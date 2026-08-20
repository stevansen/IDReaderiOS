import Foundation
import Testing

@testable import IDReaderCore

/// Zweisprachige Orts- und Adressangaben.
struct BilingualTextTests {

    @Test("der Ortsname wird in einer Sprache genommen")
    func picksOneHalf() {
        #expect(
            BilingualText.pick("VALDAGNO DI TRENTO/ALDEIN, TN", preferGerman: true)
                == "ALDEIN, TN"
        )
        #expect(
            BilingualText.pick("VALDAGNO DI TRENTO/ALDEIN, TN", preferGerman: false)
                == "VALDAGNO DI TRENTO, TN"
        )
    }

    /// "16/B" ist eine Hausnummer und darf nicht zerlegt werden.
    @Test("Hausnummern bleiben unangetastet")
    func houseNumbersStay() {
        let raw = "VIA C.AUGUSTA/C.-AUGUSTA-STR., 16/B, BOLZANO/BOZEN, BZ"
        #expect(
            BilingualText.pick(raw, preferGerman: true)
                == "C.-AUGUSTA-STR., 16/B, BOZEN, BZ"
        )
        #expect(
            BilingualText.pick(raw, preferGerman: false)
                == "VIA C.AUGUSTA, 16/B, BOLZANO, BZ"
        )
    }

    /// Im Zweifel bleibt der Abschnitt unveraendert. Lieber beide Sprachen zeigen
    /// als die falsche wegwerfen.
    @Test("mehr als ein Schraegstrich bleibt stehen")
    func ambiguousSegmentStays() {
        #expect(BilingualText.pick("A/B/C", preferGerman: true) == "A/B/C")
        #expect(BilingualText.pick("12/14", preferGerman: true) == "12/14")
    }

    @Test("leer bleibt nil")
    func emptyStaysNil() {
        #expect(BilingualText.pick(nil, preferGerman: true) == nil)
        #expect(BilingualText.pick("   ", preferGerman: true) == nil)
    }
}

/// Der Text, der die App verlaesst.
struct DocumentExportTests {

    private let german = DocumentExport(strings: Strings(language: .de))
    private let italian = DocumentExport(strings: Strings(language: .it))

    /// Ein Pass darf in der Ueberschrift nicht "CARTA D'IDENTITÀ ELETTRONICA"
    /// heissen - dieser Text landet unveraendert im Einsatzbericht.
    @Test("die Ueberschrift benennt das Dokument")
    func titleNamesTheDocument() {
        let card = german.structure(Sample.record(Sample.chipData(documentCode: "ID")))
        let passport = german.structure(Sample.record(Sample.chipData(documentCode: "P")))
        let licence = german.structure(Sample.record(LicenceInput.sample.toDocumentData()))

        #expect(card.title == "CARTA D'IDENTITÀ ELETTRONICA")
        #expect(passport.title == "PASSAPORTO")
        #expect(licence.title == "PATENTE DI GUIDA")
    }

    /// Bei einem Foto waere die Zeile "Echtheit" selbst die Unwahrheit: sie
    /// behauptet, es habe eine Pruefung gegeben, und nennt deren Ausgang.
    @Test("ein Foto bekommt keine Echtheitszeile, sondern eine Herkunftszeile")
    func photoRecordHasNoAuthenticityRow() {
        let record = german.structure(Sample.record(LicenceInput.sample.toDocumentData()))
        let labels = record.sections.flatMap(\.rows).map(\.label)

        #expect(!labels.contains("Echtheit"))
        #expect(labels.contains("Herkunft der Angaben"))
        #expect(record.notice?.hasPrefix("NICHT GEPRÜFT") == true)
    }

    @Test("ein Chip-Datensatz bekommt die Echtheitszeile und keinen Vorbehalt")
    func chipRecordHasAuthenticityRow() {
        let record = german.structure(Sample.record(Sample.chipData()))
        let rows = record.sections.flatMap(\.rows)

        #expect(rows.contains { $0.label == "Echtheit" && $0.value == "Echtheit bestätigt" })
        #expect(record.notice == nil)
    }

    /// Die Sprache entscheidet auch darueber, welche Haelfte einer zweisprachigen
    /// Ortsangabe im Bericht steht.
    @Test("die Sprache greift durch bis in die Ortsangabe")
    func languageReachesThePlaceName() {
        let record = Sample.record(Sample.chipData())
        func placeOfBirth(_ export: DocumentExport, label: String) -> String? {
            export.structure(record).sections
                .flatMap(\.rows)
                .first { $0.label == label }?
                .value
        }

        #expect(placeOfBirth(german, label: "Geburtsort") == "BOZEN, BZ")
        #expect(placeOfBirth(italian, label: "Luogo di nascita") == "BOLZANO, BZ")
    }

    /// Die Spaltenbreite kommt aus den tatsaechlich vorkommenden Beschriftungen:
    /// "Staatsangehoerigkeit" und "Cittadinanza" sind verschieden lang, und eine
    /// zu knappe feste Breite laesst die Spalte in einer der Sprachen ausfransen.
    @Test("die lesbare Fassung richtet die Spalten aus", arguments: [AppLanguage.de, .it, .en])
    func readableTextAlignsColumns(language: AppLanguage) {
        let export = DocumentExport(strings: Strings(language: language))
        let record = Sample.record(Sample.chipData())
        let text = export.build([record], format: .readable)
        let lines = text.split(separator: "\n").map(String.init)

        // Die Spalte wird am Wert gemessen, nicht am Leerraum: eine Beschriftung
        // kann Leerzeichen enthalten, und "das erste doppelte Leerzeichen" ist
        // deshalb nicht der Anfang der Wertspalte.
        var columns: Set<Int> = []
        for row in export.structure(record).sections.flatMap(\.rows) {
            guard let line = lines.first(where: { $0.hasPrefix("  " + row.label) }),
                  let range = line.range(of: row.value, options: .backwards)
            else {
                Issue.record("Zeile fuer '\(row.label)' nicht gefunden")
                continue
            }
            columns.insert(line.distance(from: line.startIndex, to: range.lowerBound))
        }
        #expect(columns.count == 1)
    }

    @Test("die Schlusszeile sagt die Wahrheit ueber das Lichtbild")
    func closingLineTellsTheTruth() {
        let record = Sample.record(Sample.chipData())
        #expect(german.build([record], format: .readable, photosAttached: false)
            .hasSuffix("Das Lichtbild ist in diesem Export nicht enthalten."))
        #expect(german.build([record], format: .readable, photosAttached: true)
            .hasSuffix("Das Lichtbild liegt dieser Nachricht als Anhang bei."))
    }

    // -----------------------------------------------------------------------
    // JSON
    // -----------------------------------------------------------------------

    private func json(_ documents: [StoredDocument], _ export: DocumentExport) throws
        -> [String: Any] {
        let text = export.build(documents, format: .json)
        return try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    }

    /// `name` ist der **Vorname**, `surname` der Nachname - das Importskript gibt
    /// beide als `"Name: {name} {surname}"` aus.
    @Test("die Feldnamen sind die des Importskripts")
    func jsonFieldNames() throws {
        let root = try json([Sample.record(Sample.chipData())], german)
        let person = (root["people"] as! [[String: Any]])[0]

        #expect(person["surname"] as? String == "MUSTERMANN")
        #expect(person["name"] as? String == "ANITA")
        #expect(person["birthdate"] as? String == "1968-04-07")
        #expect(person["documenttype"] as? String == "ID/CI")
        #expect(person["documentnr"] as? String == "CA12345AB")
        // Vorhanden, weil das Importskript ohne diesen Schluessel abbricht; leer,
        // damit es einen erfassten Berichtstext nicht ueberschreibt.
        #expect((root["report_sections"] as? [String: Any])?.isEmpty == true)
    }

    /// Das Skript bricht an einem ungueltigen Datum ab; bei einem fehlenden setzt
    /// es selbst ein Ersatzdatum. Also lieber JSON-null als ein Wert, der den
    /// ganzen Import anhaelt.
    @Test("ein unvollstaendiges Geburtsdatum wird null, nicht geraten")
    func incompleteBirthdateBecomesNull() throws {
        var input = LicenceInput.sample
        input.dateOfBirth = "3.4.1985"
        let root = try json([Sample.record(input.toDocumentData())], german)
        let person = (root["people"] as! [[String: Any]])[0]

        #expect(person["birthdate"] is NSNull)
    }

    /// Ein Bericht soll einen Ortsnamen enthalten, nicht zwei.
    @Test("das JSON folgt derselben Sprache wie der Text")
    func jsonFollowsTheLanguage() throws {
        let record = Sample.record(Sample.chipData())
        let de = (try json([record], german)["people"] as! [[String: Any]])[0]
        let it = (try json([record], italian)["people"] as! [[String: Any]])[0]

        #expect(de["birthlocation"] as? String == "BOZEN, BZ")
        #expect(it["birthlocation"] as? String == "BOLZANO, BZ")
    }

    @Test("Sonderzeichen kommen in der HTML-Fassung nicht durch")
    func htmlIsEscaped() {
        var data = Sample.chipData(surname: "<script>")
        data.givenNames = "A & B"
        let html = german.buildHtml([Sample.record(data)])

        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("A &amp; B"))
        #expect(!html.contains("<script>"))
    }
}

/// Der Lokalisierungskatalog.
struct LocalizationTests {

    /// Jeder Schluessel in jeder Sprache.
    ///
    /// Der eigentliche Grund fuer diesen Test: der Katalog ist aus dem
    /// Android-Original erzeugt, und ein Schluessel, der dort `translatable=false`
    /// trug oder beim Uebertragen ausfiel, faellt hier auf - und nicht erst, wenn
    /// im Bericht der Schluesselname statt eines Textes steht.
    @Test("kein Schluessel fehlt", arguments: AppLanguage.allCases)
    func everyKeyResolves(language: AppLanguage) {
        let strings = Strings(language: language)
        let missing = StringKey.allCases.filter { strings[$0] == $0.rawValue }
        #expect(missing.isEmpty, Comment(rawValue: "fehlt in \(language.rawValue): "
            + missing.map(\.rawValue).joined(separator: ", ")))
    }

    @Test("keine Zaehlangabe fehlt", arguments: AppLanguage.allCases)
    func everyPluralResolves(language: AppLanguage) {
        let strings = Strings(language: language)
        for key in PluralKey.allCases {
            #expect(strings.plural(key, 1) != "1")
            #expect(strings.plural(key, 5) != "5")
        }
    }

    /// Welche Haelfte einer zweisprachigen Ortsangabe genommen wird, haengt an
    /// derselben Entscheidung, die die Texte auswaehlt.
    @Test("nur die deutsche Fassung bevorzugt Deutsch")
    func onlyGermanPrefersGerman() {
        #expect(Strings(language: .de).prefersGerman)
        #expect(!Strings(language: .it).prefersGerman)
        #expect(!Strings(language: .en).prefersGerman)
    }

    @Test("Platzhalter werden gefuellt")
    func placeholdersAreFilled() {
        let strings = Strings(language: .de)
        #expect(strings.format(.resultRetentionHint, 30) == "Bleibt 30 Tage verschlüsselt auf diesem Gerät.")
        #expect(strings.format(.menuVersion, "2.0") == "Version 2.0")
        #expect(strings.plural(.archiveTitle, 1) == "1 Scan")
        #expect(strings.plural(.archiveTitle, 5) == "5 Scans")
    }
}

extension LicenceInput {
    /// Eine ausgefuellte Maske, wie sie nach einer Aufnahme dasteht.
    static var sample: LicenceInput {
        LicenceInput.from(
            LicenceScan.Fields(
                surname: "RAAB",
                givenNames: "SEBASTIAN",
                dateOfBirth: "02.09.1965",
                placeOfBirth: "BOLZANO-BOZEN (BZ)",
                dateOfIssue: "08.06.2015",
                dateOfExpiry: "02.09.2026",
                issuingAuthority: "MIT-UCO",
                number: "U1X830164P",
                categories: "A B"
            )
        )
    }
}

/// Die hinterlegten Vertrauensanker.
struct CscaTrustStoreTests {

    /// Ohne diese Zertifikate ist der dritte Schritt der Echtheitspruefung nicht
    /// zu machen - und der ist der, auf den es ankommt. Ein Bundle, das sie beim
    /// Umbauen verliert, faellt hier auf und nicht erst am Ausweis.
    @Test("neun italienische CSCA-Zertifikate liegen bei")
    func certificatesArePresent() {
        let anchors = CscaTrustStore.load()
        #expect(anchors.count == 9)
        // Jedes muss mit einer DER-SEQUENCE beginnen; eine leere oder
        // versehentlich in PEM umgewandelte Datei faellt damit auf.
        #expect(anchors.allSatisfy { $0.first == 0x30 })
    }
}
