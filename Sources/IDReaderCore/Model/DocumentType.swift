import Foundation

/// Werte fuer `documenttype` in `dbo.people`, hoechstens 50 Zeichen.
///
/// Die Schreibweise ist von der Fachanwendung vorgegeben und darf nicht frei
/// gewaehlt werden - ein abweichender Wert landet als eigener Dokumenttyp in der
/// Datenbank.
public enum DocumentType: Sendable, CaseIterable {
    /// Identitaetskarte, italienisch carta d'identita.
    case identityCard
    /// Reisepass.
    case passport
    /// Italienische Fahrerlaubnis.
    case drivingLicence

    /// Der Wert, der in den Bericht geht.
    public var reportValue: String {
        switch self {
        case .identityCard: "ID/CI"
        case .passport: "Pass"
        case .drivingLicence: "FS/Pat"
        }
    }

    /// Ueberschrift des Datensatzes - benennt das Dokument, das gelesen wurde.
    ///
    /// Nicht nur Zierde: derselbe Text steht in der Ueberschrift des Exports und
    /// damit im Einsatzbericht. Ein Pass, der dort als Identitaetskarte
    /// ausgewiesen wird, ist eine falsche Angabe in einem Bericht.
    public var titleKey: StringKey {
        switch self {
        case .identityCard: .resultDocumentType
        case .passport: .resultDocumentTypePassport
        case .drivingLicence: .resultDocumentTypeLicence
        }
    }

    /// Ordnet den Dokumentencode der MRZ nach ICAO 9303 zu.
    ///
    /// Entscheidend ist nur der erste Buchstabe. Paesse tragen "P", oft mit
    /// einem zweiten Zeichen ("PM" fuer einen Dienstpass, "PD" fuer einen
    /// Diplomatenpass). Karten tragen "I", "A" oder "C", ebenfalls mit
    /// wechselndem zweitem Zeichen - "ID", "IR", "AC". Auf die volle Liste zu
    /// pruefen waere fehleranfaellig, weil sie je Staat erweitert wird.
    ///
    /// Ein fehlender oder unbekannter Code ergibt ``identityCard``.
    public static func of(documentCode: String?) -> DocumentType {
        let first = documentCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .first
        return first == "P" ? .passport : .identityCard
    }

    /// Die Art eines Datensatzes.
    ///
    /// Nicht allein am Dokumentencode: eine Fahrerlaubnis hat keine MRZ und
    /// damit keinen Code, und ohne diese Unterscheidung fiele sie in jeder
    /// Ableitung auf die Identitaetskarte zurueck - Ueberschrift, Archivkachel,
    /// Farbwelt und der Wert im Bericht. Die Herkunft entscheidet zuerst.
    public static func of(_ data: DocumentData) -> DocumentType {
        switch data.provenance {
        case .photo: .drivingLicence
        case .chip: of(documentCode: data.documentCode)
        }
    }
}

/// Welche Dokumentart die App gerade lesen soll.
///
/// Die Wahl muss vor dem Auflegen fallen, weil sich die Dokumentarten im
/// Zugangsschluessel unterscheiden: die CIE braucht die aufgedruckte CAN, ein
/// Pass drei Felder aus der maschinenlesbaren Zone. Vom Chip selbst laesst sich
/// das nicht vorher erfragen - ohne gesicherte Verbindung gibt er nichts heraus,
/// und die gesicherte Verbindung ist genau das, wofuer der Schluessel gebraucht
/// wird.
public enum DocumentMode: Sendable, Hashable, CaseIterable, Identifiable {
    case identityCard
    case passport
    /// Italienische Fahrerlaubnis. Kein Chip, kein Schluessel, keine Pruefung -
    /// die Angaben kommen ausschliesslich aus der Texterkennung eines Fotos.
    case drivingLicence

    public var id: Self { self }

    /// Ob diese Art ueber einen Chip gelesen wird.
    public var readsChip: Bool { self != .drivingLicence }

    /// Die Arten, die der Umschalter im Kopfbereich anbietet.
    ///
    /// Eine eigene Liste und nicht `allCases`: der Umschalter soll nicht still
    /// mitwachsen, wenn hier eine Art hinzukommt. Drei nebeneinander sind auf
    /// einem schmalen Geraet bereits die Grenze.
    public static let switchable: [DocumentMode] = [.identityCard, .passport, .drivingLicence]

    public var labelKey: StringKey {
        switch self {
        case .identityCard: .modeIdentityCard
        case .passport: .modePassport
        case .drivingLicence: .modeLicence
        }
    }

    /// Die Betriebsart eines Datensatzes.
    ///
    /// Ueber ``DocumentType/of(_:)``, damit die Herkunft mitentscheidet: eine
    /// Fahrerlaubnis hat keinen Dokumentencode und fiele sonst auf die
    /// Identitaetskarte zurueck.
    public static func of(_ data: DocumentData) -> DocumentMode {
        switch DocumentType.of(data) {
        case .passport: .passport
        case .identityCard: .identityCard
        case .drivingLicence: .drivingLicence
        }
    }

    public static func of(documentCode: String?) -> DocumentMode {
        switch DocumentType.of(documentCode: documentCode) {
        case .passport: .passport
        case .identityCard: .identityCard
        case .drivingLicence: .drivingLicence
        }
    }
}
