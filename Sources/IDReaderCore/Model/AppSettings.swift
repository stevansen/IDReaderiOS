import Foundation

/// Verfuegbare Ausgabeformate fuer den Export.
public enum ExportFormat: String, Sendable, CaseIterable, Identifiable {
    /// Fuer Menschen: beschriftete Zeilen, gruppiert, in der App-Sprache.
    case readable = "READABLE"
    /// Fuer die Uebernahme in den Einsatzbericht: JSON mit dem Feld `people`.
    case json = "JSON"

    public var id: String { rawValue }

    public var labelKey: StringKey {
        switch self {
        case .readable: .shareFormatReadable
        case .json: .shareFormatJson
        }
    }
}

/// Die wenigen Einstellungen, die die App sich merkt.
///
/// Bewusst getrennt vom Archiv und bewusst unverschluesselt: hier steht die
/// Mailadresse des Benutzers selbst, also die Stelle, an die er seine eigenen
/// Ausleseergebnisse schickt. Das ist kein Personendatum eines Dritten, und ein
/// Schluessel aus dem Schluesselbund waere dafuer aufwendiger, ohne etwas zu
/// schuetzen, was nicht ohnehin in jeder gesendeten Mail steht.
///
/// Ausweisdaten gehoeren hier nie hinein - die liegen verschluesselt im
/// ``DocumentArchive``.
/// `@unchecked Sendable`: `UserDefaults` ist laut Dokumentation threadsicher,
/// traegt die Kennzeichnung aber nicht.
public struct AppSettings: @unchecked Sendable {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Fassung des Hinweises beim ersten Start.
    ///
    /// **Diese Zahl erhoehen, sobald sich der Text inhaltlich aendert.** Dann
    /// erscheint der Hinweis erneut, und der Bediener bestaetigt die Fassung, die
    /// er tatsaechlich gelesen hat. Ohne das waere ein spaeter geaenderter Text von
    /// niemandem zur Kenntnis genommen - und die Bestaetigung im Speicher waere ein
    /// Beleg fuer einen Text, den es nicht mehr gibt.
    ///
    /// Reine Sprach- oder Satzbaukorrekturen sind kein Grund; eine geaenderte
    /// Aussage ist einer.
    public static let noticeVersion = 1

    // -----------------------------------------------------------------------

    /// Hinterlegte Empfaengeradresse, leer wenn keine gesetzt ist.
    public var shareEmail: String {
        get { defaults.string(forKey: Key.shareEmail) ?? "" }
        nonmutating set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Eine leere Eingabe loescht den Eintrag, damit man ihn ohne Umweg
            // wieder loswird.
            if trimmed.isEmpty {
                defaults.removeObject(forKey: Key.shareEmail)
            } else {
                defaults.set(trimmed, forKey: Key.shareEmail)
            }
        }
    }

    /// Zuletzt benutztes Ausgabeformat.
    ///
    /// Wer einmal JSON gewaehlt hat, will es beim naechsten Export meistens
    /// wieder. Ein unbekannter oder fehlender Wert faellt auf die lesbare Fassung
    /// zurueck - etwa wenn ein spaeteres Update ein Format umbenennt.
    public var exportFormat: ExportFormat {
        get {
            defaults.string(forKey: Key.exportFormat)
                .flatMap(ExportFormat.init(rawValue:)) ?? .readable
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.exportFormat) }
    }

    /// Ob **alle** gelesenen Felder aufbewahrt werden.
    ///
    /// Vorgabe ist `false`, und die Richtung der Vorgabe ist die Aussage: Wohnsitz,
    /// Steuernummer, Beruf und Telefon werden angezeigt und nicht behalten, weil
    /// kein Anwendungsfall sie braucht, nachdem das Dokument aus der Hand ist.
    ///
    /// Wer sie braucht - weil ein Bericht danach fragt, den die App nicht kennt -
    /// schaltet das hier um. Dann liegen sie im Archiv und gehen in jeden Export
    /// mit, und die Verantwortung dafuer liegt bei dem, der umgeschaltet hat.
    ///
    /// Rueckwirkend gilt es nicht. Was einmal weggelassen wurde, ist weg; ein
    /// Umschalten wirkt auf das, was danach gelesen wird.
    public var retainsAllFields: Bool {
        get { defaults.bool(forKey: Key.retainAllFields) }
        nonmutating set { defaults.set(newValue, forKey: Key.retainAllFields) }
    }

    /// Gewaehlte Sprache.
    public var language: AppLanguage {
        get { AppLanguage(tag: defaults.string(forKey: Key.language)) }
        nonmutating set {
            if let tag = newValue.tag {
                defaults.set(tag, forKey: Key.language)
            } else {
                defaults.removeObject(forKey: Key.language)
            }
        }
    }

    /// Ob der Hinweis beim ersten Start in seiner heutigen Fassung bestaetigt ist.
    ///
    /// Verglichen wird auf "mindestens": wer Fassung 2 bestaetigt hat, bekommt nach
    /// einem Ruecksprung auf Fassung 1 nicht noch einmal denselben Bildschirm.
    public var noticeAcknowledged: Bool {
        defaults.integer(forKey: Key.noticeVersion) >= AppSettings.noticeVersion
    }

    /// Vermerkt Fassung und Zeitpunkt der Bestaetigung.
    ///
    /// Der Zeitpunkt ist kein Einwilligungsnachweis - eine Einwilligung ist das
    /// hier nicht. Er ist die Auskunft, wann jemandem gesagt wurde, dass die
    /// Verantwortung bei ihm liegt. Wer die App weitergibt oder eine Beschwerde
    /// beantworten muss, hat damit ein Datum.
    public func acknowledgeNotice() {
        defaults.set(AppSettings.noticeVersion, forKey: Key.noticeVersion)
        defaults.set(currentTimeMillis(), forKey: Key.noticeAt)
    }

    /// Zeitpunkt der Bestaetigung, oder 0 wenn nie bestaetigt wurde.
    public var noticeAcknowledgedAt: Int64 {
        Int64(defaults.integer(forKey: Key.noticeAt))
    }

    /// Grobe Pruefung, ob sich an die Eingabe ueberhaupt senden laesst.
    ///
    /// Absichtlich nachsichtig: eine strenge Pruefung nach RFC lehnt gueltige
    /// Adressen ab, und der eigentliche Test ist ohnehin, ob das Mailprogramm die
    /// Adresse annimmt. Es geht hier nur darum, den Senden-Knopf nicht anzubieten,
    /// solange offensichtlich nichts Vollstaendiges dasteht.
    public static func looksLikeEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"),
              at != trimmed.startIndex,
              trimmed.lastIndex(of: "@") == at
        else { return false }

        let domain = trimmed[trimmed.index(after: at)...]
        return domain.count >= minDomainLength
            && domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && !trimmed.contains(where: \.isWhitespace)
    }

    /// "a.b" - kuerzer kann eine Domain mit Punkt nicht sein.
    private static let minDomainLength = 3

    private enum Key {
        static let shareEmail = "share_email"
        static let exportFormat = "export_format"
        static let noticeVersion = "notice_version"
        static let noticeAt = "notice_at"
        static let language = "language"
        static let retainAllFields = "retain_all_fields"
    }
}
