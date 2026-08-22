import Foundation

/// Erzeugt den Text, der die App verlaesst.
///
/// Bewusst als reiner Text und nicht als Datei: so gibt es nichts, was im Cache
/// liegen bleibt, und der Nutzer sieht vor dem Teilen genau, was weitergegeben
/// wird.
///
/// Das Lichtbild wird nie in den Text exportiert. Ein Bild laesst sich weder
/// sinnvoll in Text giessen noch vorher pruefen; wer es braucht, sieht es in der
/// App oder bekommt es als Anhang einer Mail.
///
/// Der Export enthaelt alle gelesenen Angaben, ohne Auswahl. Frueher gab es dafuer
/// Schalter; sie sind entfallen, weil sie eine Entscheidung verlangten, die im
/// Einsatz niemand treffen will.
///
/// Von der Echtheitspruefung steht hier nur das Ergebnis. Womit geprueft wurde -
/// Hashverfahren, Signierer, Zertifikatskette - gehoert nicht in einen Bericht;
/// das steht in der App hinter dem Echtheitssiegel.
public struct DocumentExport: Sendable {

    /// Der Katalog, in dem dieser Export formuliert wird.
    ///
    /// Nicht privat: die HTML-Fassung liegt in einer eigenen Datei, und zwei
    /// Kataloge in einem Export waeren zwei Sprachen in einem Bericht.
    public let strings: Strings

    public init(strings: Strings) {
        self.strings = strings
    }

    /// Ein oder mehrere Lesevorgaenge als Text.
    ///
    /// `photosAttached` steuert nur die Schlusszeile. Sie muss stimmen: die
    /// Zusage, dass kein Lichtbild dabei ist, darf nicht in einer Nachricht
    /// stehen, an der eines haengt.
    public func build(
        _ documents: [StoredDocument],
        format: ExportFormat,
        photosAttached: Bool = false
    ) -> String {
        switch format {
        case .readable:
            return buildReadable(documents, photosAttached: photosAttached)
        // Der JSON-Fassung liegt nie ein Bild bei.
        case .json:
            return buildJson(documents)
        }
    }

    // -----------------------------------------------------------------------
    // Lesbare Fassung
    // -----------------------------------------------------------------------

    private func buildReadable(_ documents: [StoredDocument], photosAttached: Bool) -> String {
        var out = ""

        if documents.count > 1 {
            out += strings.plural(.exportCollectionHeader, documents.count) + "\n"
            out += strings.format(.exportCreatedAt, timestamp(Date())) + "\n\n"
        }

        for (index, document) in documents.enumerated() {
            if index > 0 {
                out += "\n" + DocumentExport.separator + "\n\n"
            }
            out += readableRecord(document) + "\n"
        }

        out += "\n" + strings[photosAttached ? .exportPhotoAttached : .exportNoPhoto] + "\n"
        return out.trimmingTrailingWhitespaceAndNewlines()
    }

    private func readableRecord(_ document: StoredDocument) -> String {
        let record = structure(document)

        // Spaltenbreite aus den tatsaechlich vorkommenden Beschriftungen, nicht
        // fest verdrahtet: "Staatsangehoerigkeit", "Cittadinanza" und
        // "Nationality" sind verschieden lang, und eine zu knappe feste Breite
        // laesst die Spalte in einer der Sprachen ausfransen.
        let widest = record.sections.flatMap(\.rows).map(\.label.count).max() ?? 0
        let width = widest + DocumentExport.columnGap

        var out = record.title + "\n" + record.subtitle + "\n"
        if let notice = record.notice {
            out += "\n" + notice + "\n"
        }

        for section in record.sections {
            out += "\n" + section.title + "\n"
            for row in section.rows {
                out += "  " + row.label.padding(toLength: width) + row.value + "\n"
            }
        }
        return out.trimmingTrailingWhitespaceAndNewlines()
    }

    /// Aufbau eines Datensatzes fuer die lesbare Ausgabe.
    ///
    /// Wird sowohl fuer den Text als auch fuer die Vorschau im Teilen-Schirm
    /// verwendet. Beides aus derselben Quelle, damit die Vorschau nicht etwas
    /// anderes zeigt als das, was tatsaechlich hinausgeht.
    public func structure(_ document: StoredDocument) -> ExportRecord {
        let data = document.data
        let missing = strings[.valueMissing]
        let notRetained = strings[.valueNotRetained]
        let preferGerman = strings.prefersGerman

        /// „Nicht im Dokument" und „gelesen, nicht gespeichert" sind zwei
        /// verschiedene Auskuenfte. Ein Bericht, der die zweite als die erste
        /// ausgibt, behauptet, das Dokument habe etwas nicht gefuehrt - und das
        /// ist eine Aussage ueber das Dokument, die hier niemand treffen darf.
        func absent(_ field: MinimisedField) -> String {
            data.wasDropped(field) ? notRetained : missing
        }

        var documentRows: [ExportRow] = [
            row(.labelDocumentNumber, data.documentNumber)
        ]
        if let issuingState = data.issuingState {
            documentRows.append(row(.labelIssuingState, issuingState))
        }
        documentRows.append(row(.labelDateOfExpiry, data.dateOfExpiry))
        if let dateOfIssue = data.dateOfIssue {
            documentRows.append(row(.labelDateOfIssue, dateOfIssue))
        } else if data.provenance == .chip {
            // Eine fehlende Zeile im Bericht liest sich als Versehen, „nicht im
            // Dokument" waere eine Aussage ueber das Dokument, die nicht stimmt:
            // der italienische Reisepass traegt das Ausstellungsdatum gedruckt
            // auf der Datenseite und fuehrt kein DG12. Also die dritte Auskunft.
            documentRows.append(row(.labelDateOfIssue, strings[.valueNotOnChip]))
        }
        // Die ausstellende Gemeinde steht in Suedtirol zweisprachig auf der Karte.
        if let authority = BilingualText.pick(data.issuingAuthority, preferGerman: preferGerman) {
            documentRows.append(row(.labelIssuingAuthority, authority))
        }
        // Bei einem Foto waere die Zeile "Echtheit" selbst die Unwahrheit: sie
        // behauptet, es habe eine Pruefung gegeben, und nennt deren Ausgang. Also
        // eine andere Zeile.
        if data.provenance == .photo {
            documentRows.append(row(.labelProvenance, strings[.valueProvenancePhoto]))
        } else {
            documentRows.append(
                row(.exportLabelResult, strings[label(for: data.authenticity.status)])
            )
        }

        let personSection = ExportSection(
            title: strings[.exportSectionPerson],
            rows: [
                row(.labelSurname, data.surname),
                row(.labelGivenNames, data.givenNames),
                row(.labelDateOfBirth, data.dateOfBirth),
                row(.labelGender, strings[label(for: data.gender)]),
                row(.labelNationality, data.nationality),
                row(
                    .labelPlaceOfBirth,
                    BilingualText.pick(data.placeOfBirth, preferGerman: preferGerman) ?? missing
                ),
                row(
                    .labelResidence,
                    BilingualText.pick(data.residence, preferGerman: preferGerman)
                        ?? absent(.residence)
                ),
                row(.labelCodiceFiscale, data.codiceFiscale ?? absent(.codiceFiscale)),
            ]
        )

        let sections = [
            personSection,
            ExportSection(title: strings[.exportSectionDocument], rows: documentRows),
        ] + extraSection(data)

        return ExportRecord(
            // Die Ueberschrift benennt das Dokument. Ein Pass darf hier nicht
            // "CARTA D'IDENTITA ELETTRONICA" heissen - dieser Text landet
            // unveraendert im Einsatzbericht.
            title: strings[DocumentType.of(data).titleKey],
            subtitle: strings.format(.exportScannedAt, timestamp(document.storedDate)),
            sections: sections,
            notice: data.provenance == .photo ? strings[.exportNoticePhoto] : nil
        )
    }

    private func row(_ key: StringKey, _ value: String) -> ExportRow {
        ExportRow(label: strings[key], value: value)
    }

    /// Die uebrigen Angaben aus DG11 und DG12, sofern das Dokument sie fuehrt.
    ///
    /// Nur die vorhandenen: auf den allermeisten Dokumenten ist hier nichts
    /// gesetzt, und ein Abschnitt aus neun Zeilen "nicht im Dokument" waere in
    /// einem Bericht Ballast. Fehlt alles, faellt der Abschnitt ganz weg.
    private func extraSection(_ data: DocumentData) -> [ExportSection] {
        // Beim Fuehrerschein stehen hier die Klassen, und die kommen aus dem Foto.
        // Die Ueberschrift "vom Chip" waere an dieser Stelle schlicht falsch,
        // deshalb zwei Fassungen derselben Ueberschrift.
        let title = strings[
            data.provenance == .photo ? .exportSectionExtraDocument : .exportSectionExtra
        ]

        // Beruf und Telefon werden nicht aufbewahrt. Standen sie im Dokument,
        // gehoert das in den Bericht - nicht der Wert, aber die Tatsache. Wer
        // spaeter fragt, warum dort nichts steht, findet die Antwort.
        let notRetained = strings[.valueNotRetained]
        let candidates: [(StringKey, String?)] = [
            (.labelCategories, data.categories),
            (.labelOtherNames, data.otherNames),
            (.labelTitle, data.title),
            (.labelProfession, data.profession
                ?? (data.wasDropped(.profession) ? notRetained : nil)),
            (.labelPersonalSummary, data.personalSummary),
            (.labelTelephone, data.telephone
                ?? (data.wasDropped(.telephone) ? notRetained : nil)),
            (.labelOtherDocuments, data.otherValidDocuments),
            (.labelCustody, data.custodyInformation),
            (.labelEndorsements, data.endorsements),
            (.labelTaxExit, data.taxOrExitRequirements),
        ]
        let rows = candidates.compactMap { key, value in
            value.map { row(key, $0) }
        }

        if rows.isEmpty { return [] }
        return [ExportSection(title: title, rows: rows)]
    }

    // -----------------------------------------------------------------------
    // JSON
    // -----------------------------------------------------------------------

    /// JSON in der Form, die der Einsatzbericht erwartet.
    ///
    /// Oberste Ebene ist `people`, weil dort die personenbezogenen Dokumentdaten
    /// stehen sollen und nirgends sonst. Jeder Eintrag ist flach gehalten: eine
    /// Berichtsvorlage greift einzelne Felder ab, und dafuer ist eine
    /// Verschachtelung nur im Weg.
    ///
    /// Ort, Adresse und ausstellende Stelle folgen der Sprache der App statt
    /// beide Sprachen mit Schraegstrich zu liefern. Ein Bericht soll einen
    /// Ortsnamen enthalten, nicht zwei.
    ///
    /// Die Feldnamen sind gegen `import_report_from_clipboard.py` abgeglichen, das
    /// die Eintraege nach `dbo.people` schreibt. Sie stehen alle in ``jsonPerson``
    /// und nur dort.
    ///
    /// `report_sections` ist leer, aber vorhanden. Vorhanden, weil das
    /// Importskript ohne diesen Schluessel abbricht. Leer, weil es nur
    /// tatsaechlich gelieferte Abschnitte schreibt - ein leeres Objekt laesst einen
    /// bereits erfassten Berichtstext also unberuehrt, waehrend leere
    /// Zeichenketten ihn ueberschrieben haetten.
    private func buildJson(_ documents: [StoredDocument]) -> String {
        let root: [String: Any] = [
            "source": "IDReader",
            "exportedAt": isoTimestamp(Date()),
            "report_sections": [String: Any](),
            "people": documents.map { jsonPerson($0, preferGerman: strings.prefersGerman) },
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// Ein Eintrag fuer `people`, in den Feldnamen des Importskripts.
    ///
    /// Zuordnung, die nicht offensichtlich ist: `name` ist der **Vorname**,
    /// `surname` der Nachname. Das Skript gibt beide als
    /// `"Name: {name} {surname}"` aus, also Vorname zuerst.
    ///
    /// `birthdate` muss `JJJJ-MM-TT` sein und kalendarisch stimmen, sonst bricht
    /// das Skript ab. Fehlt es, setzt das Skript selbst ein Ersatzdatum; deshalb
    /// wird hier nichts erfunden.
    private func jsonPerson(_ document: StoredDocument, preferGerman: Bool) -> [String: Any] {
        let data = document.data

        func orNull(_ value: String?) -> Any {
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
                return NSNull()
            }
            return value
        }

        // Nur ein Datum, das wirklich JJJJ-MM-TT ist. Bei der Fahrerlaubnis sind
        // die Felder frei bearbeitbar - dort kann "3.4.1985" oder gar nichts
        // stehen. Das Skript bricht an einem ungueltigen Datum ab; bei einem
        // fehlenden setzt es selbst ein Ersatzdatum. Also lieber JSON-null als ein
        // Wert, der den ganzen Import anhaelt.
        let iso = DocumentExport.toIsoDate(data.dateOfBirth)

        return [
            "surname": data.surname,
            "name": data.givenNames,
            "birthdate": DocumentExport.isIsoDate(iso) ? iso : NSNull(),
            "birthlocation": orNull(
                BilingualText.pick(data.placeOfBirth, preferGerman: preferGerman)
            ),
            "address": orNull(BilingualText.pick(data.residence, preferGerman: preferGerman)),
            "documenttype": DocumentType.of(data).reportValue,
            "documentnr": data.documentNumber,
        ]
    }

    // -----------------------------------------------------------------------
    // Beschriftungen
    // -----------------------------------------------------------------------

    private func label(for gender: Gender) -> StringKey {
        switch gender {
        case .male: .genderMale
        case .female: .genderFemale
        case .unknown: .genderUnknown
        }
    }

    private func label(for status: AuthenticityStatus) -> StringKey {
        switch status {
        case .verified: .authenticityVerified
        case .failed: .authenticityFailed
        case .notChecked: .authenticityNotChecked
        // Kommt in der Ausgabe nicht vor: fuer ein Foto steht dort die Herkunft.
        case .unverifiable: .valueProvenancePhoto
        }
    }

    // -----------------------------------------------------------------------
    // Hilfen
    // -----------------------------------------------------------------------

    /// Streng JJJJ-MM-TT - genau das, was das Importskript verlangt.
    static func isIsoDate(_ value: String) -> Bool {
        isoDate.matches(value)
    }

    /// TT.MM.JJJJ -> JJJJ-MM-TT. Laesst alles unveraendert, was nicht diesem
    /// Muster entspricht - im Zweifel lieber das Original als ein erfundenes
    /// Datum.
    static func toIsoDate(_ value: String) -> String {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == DocumentExport.datePartCount else { return value }
        let day = parts[0], month = parts[1], year = parts[2]
        guard day.count == 2, month.count == 2, year.count == 4 else { return value }
        guard value.allSatisfy({ $0.isNumber || $0 == "." }) else { return value }
        return "\(year)-\(month)-\(day)"
    }

    private func timestamp(_ date: Date) -> String {
        // Feste Schreibweise und keine des Systems: derselbe Text steht in einem
        // Bericht, der weitergereicht wird, und der soll nicht davon abhaengen,
        // welches Zahlenformat auf dem Telefon eingestellt war.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date)
    }

    private func isoTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.string(from: date)
    }

    private static let separator = "----------------------------------------"

    /// Abstand zwischen Beschriftungs- und Wertspalte.
    private static let columnGap = 2
    private static let datePartCount = 3
    private static let isoDate = Pattern("\\d{4}-\\d{2}-\\d{2}")
}

extension String {
    /// Rechts mit Leerzeichen auffuellen. Kuerzt nicht - eine abgeschnittene
    /// Beschriftung in einem Bericht ist schlimmer als eine ausgefranste Spalte.
    func padding(toLength length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }

    func trimmingTrailingWhitespaceAndNewlines() -> String {
        var copy = self
        while let last = copy.last, last.isWhitespace || last.isNewline {
            copy.removeLast()
        }
        return copy
    }
}
