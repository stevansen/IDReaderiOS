import Foundation
import Testing

@testable import IDReaderCore

/// Beispieldaten fuer die Tests, die einen Datensatz brauchen.
enum Sample {

    static func chipData(
        surname: String = "MUSTERMANN",
        givenNames: String = "ANITA",
        documentNumber: String = "CA12345AB",
        codiceFiscale: String? = "MSTNTA68D47A952K",
        expiry: String = "07.04.2031",
        photo: DocumentPhoto? = nil,
        documentCode: String? = "ID"
    ) -> DocumentData {
        DocumentData(
            provenance: .chip,
            surname: surname,
            givenNames: givenNames,
            dateOfBirth: "07.04.1968",
            gender: .female,
            nationality: "ITA",
            issuingState: "ITA",
            documentNumber: documentNumber,
            documentCode: documentCode,
            dateOfExpiry: expiry,
            placeOfBirth: "BOLZANO/BOZEN, BZ",
            residence: "VIA C.AUGUSTA/C.-AUGUSTA-STR., 16/B, BOLZANO/BOZEN, BZ",
            codiceFiscale: codiceFiscale,
            issuingAuthority: "MINISTERO DELL'INTERNO",
            dateOfIssue: "05.03.2019",
            photo: photo,
            authenticity: Authenticity(
                status: .verified,
                dataGroupsIntact: true,
                signatureValid: true,
                chainTrusted: true,
                chipAuthenticationExpected: true,
                chipAuthenticated: true,
                checkedDataGroups: [1, 11, 12, 14],
                signerName: "Italian Document Signer",
                trustAnchorName: "Italian CSCA",
                digestAlgorithm: "SHA-256"
            )
        )
    }

    static func record(
        _ data: DocumentData,
        storedAt: Int64 = currentTimeMillis(),
        can: String = "123456"
    ) -> StoredDocument {
        StoredDocument(data: data, storedAt: storedAt, cardId: nil, can: can)
    }

    /// Ein winziges, gueltiges JPEG - genug, um die Ablage zu pruefen.
    static let jpeg = Data(base64Encoded: """
        /9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a\
        HBwcJC4nICIsIxwcKDcpLDA1NTU1HCc/QD08Pjs1NTUBCQkJDAsMGA0NGDIhHCEyMjIyMjIyMjIy\
        MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMv/AABEIAAEAAQMBIgACEQEDEQH/\
        xAAVAAEBAAAAAAAAAAAAAAAAAAAABv/EABQBAQAAAAAAAAAAAAAAAAAAAAD/xAAUEAEAAAAAAAAA\
        AAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8AlgA//9k=
        """.replacingOccurrences(of: "\\\n", with: ""))!
}

/// Das Archivformat.
struct StoredDocumentCodecTests {

    @Test("ein Datensatz uebersteht Schreiben und Lesen unveraendert")
    func roundTrip() throws {
        let photo = DocumentPhoto(jpegData: Sample.jpeg, mimeType: "image/jp2", sizeBytes: 4711)
        let original = Sample.record(Sample.chipData(photo: photo), storedAt: 1_700_000_000_000)

        let encoded = try StoredDocumentCodec.encodeAll([original])
        let decoded = StoredDocumentCodec.decodeAll(encoded)

        #expect(decoded.count == 1)
        #expect(decoded.first == original)
    }

    /// Eine Erhoehung der Formatnummer verwirft das Archiv. Das darf aber nicht
    /// unbemerkt passieren, sonst sucht man den Fehler an der falschen Stelle.
    @Test("ein fremdes Format wird verworfen und gemeldet")
    func foreignVersionIsDiscarded() throws {
        let json = #"{"version": 7, "records": [{}]}"#.data(using: .utf8)!
        var notes: [String] = []
        let decoded = StoredDocumentCodec.decodeAll(json) { notes.append($0) }

        #expect(decoded.isEmpty)
        #expect(notes.count == 1)
        #expect(notes.first?.contains("7") == true)
    }

    /// Ein beschaedigter Eintrag soll nicht das ganze Archiv unlesbar machen,
    /// sondern nur selbst wegfallen.
    @Test("ein kaputter Eintrag nimmt die anderen nicht mit")
    func brokenRecordFallsOutAlone() throws {
        let good = try StoredDocumentCodec.encodeAll([Sample.record(Sample.chipData())])
        var root = try JSONSerialization.jsonObject(with: good) as! [String: Any]
        var records = root["records"] as! [Any]
        records.append(["storedAt": 1] as [String: Any])
        root["records"] = records

        var notes: [String] = []
        let decoded = StoredDocumentCodec.decodeAll(
            try JSONSerialization.data(withJSONObject: root),
            log: { notes.append($0) }
        )
        #expect(decoded.count == 1)
        // Zwei Meldungen, und beide gehoeren dazu: welcher Eintrag stolperte, und
        // wie viele von wie vielen es traf. Die zweite ist die, an der jemand
        // merkt, dass etwas fehlt.
        #expect(notes.count == 2)
    }

    /// Der Unterschied zwischen "steht nicht im Dokument" und "wurde als leer
    /// gelesen" ist genau das, wofuer ein Lesegeraet da ist.
    @Test("fehlende Felder bleiben null und werden nicht leer")
    func missingStaysNil() throws {
        var data = Sample.chipData(codiceFiscale: nil)
        data.residence = nil
        let encoded = try StoredDocumentCodec.encodeAll([Sample.record(data)])

        let root = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let record = (root["records"] as! [[String: Any]])[0]
        let raw = record["data"] as! [String: Any]
        #expect(raw["codiceFiscale"] is NSNull)
        #expect(raw["residence"] is NSNull)

        let decoded = StoredDocumentCodec.decodeAll(encoded)
        #expect(decoded.first?.data.codiceFiscale == nil)
        #expect(decoded.first?.data.residence == nil)
    }
}

/// Das Archiv selbst: Verschluesselung, ein Eintrag pro Person, Verfall.
struct DocumentArchiveTests {

    private func makeArchive() throws -> (DocumentArchive, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("idreader-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("archive.bin")
        return (DocumentArchive(file: file, keys: InMemoryArchiveKeyStore()), file)
    }

    @Test("was hineingelegt wurde, kommt verschluesselt zurueck")
    func addAndLoad() throws {
        let (archive, file) = try makeArchive()
        let record = Sample.record(Sample.chipData())

        #expect(archive.add(record) == [record])
        #expect(archive.load() == [record])

        // Auf der Platte darf der Name nicht zu finden sein.
        let bytes = try Data(contentsOf: file)
        #expect(!bytes.contains(Array("MUSTERMANN".utf8)))
    }

    /// Zwei Zeitpunkte, kurz hintereinander und **innerhalb** der
    /// Aufbewahrungsfrist.
    ///
    /// Feste kleine Zahlen waeren die naheliegende Wahl und sind falsch: 1000
    /// Millisekunden seit 1970 ist ein Zeitpunkt von 1970, und der ist laengst
    /// abgelaufen. Das Archiv haette die Eintraege beim Lesen weggeraeumt, und der
    /// Test haette das Zusammenfuehren nie erreicht.
    private var earlier: Int64 { currentTimeMillis() - 60_000 }
    private var later: Int64 { currentTimeMillis() - 30_000 }

    /// Dieselbe Karte: die neuen Angaben gewinnen, das Lichtbild bleibt erhalten,
    /// wenn eine der beiden Lesungen eines hat.
    @Test("ein schnelles Lesen wirft das Lichtbild nicht weg")
    func photoSurvivesFastRead() throws {
        let (archive, _) = try makeArchive()
        let photo = DocumentPhoto(jpegData: Sample.jpeg, mimeType: "image/jpeg", sizeBytes: 100)

        let first = earlier
        let second = later
        _ = archive.add(Sample.record(Sample.chipData(photo: photo), storedAt: first))
        let after = archive.add(Sample.record(Sample.chipData(photo: nil), storedAt: second))

        #expect(after.count == 1)
        #expect(after.first?.data.photo?.jpegData == Sample.jpeg)
        // Der Zeitpunkt ist der des letzten Auflegens.
        #expect(after.first?.storedAt == second)
    }

    /// Verschiedene Karten derselben Person: es gewinnt das Dokument mit dem
    /// spaeteren Ablaufdatum, samt dessen Lichtbild. Wird also die alte Karte nach
    /// der neuen gelesen, bleibt die neue stehen.
    @Test("die neu ausgestellte Karte gewinnt, auch wenn sie zuerst gelesen wurde")
    func reissuedCardWins() throws {
        let (archive, _) = try makeArchive()
        let newCard = Sample.chipData(documentNumber: "CA99999ZZ", expiry: "07.04.2035")
        let oldCard = Sample.chipData(documentNumber: "CA12345AB", expiry: "07.04.2031")

        let second = later
        _ = archive.add(Sample.record(newCard, storedAt: earlier))
        let after = archive.add(Sample.record(oldCard, storedAt: second))

        #expect(after.count == 1)
        #expect(after.first?.data.documentNumber == "CA99999ZZ")
        #expect(after.first?.storedAt == second)
    }

    /// Ohne Codice Fiscale steht die Dokumentennummer fuer die Person ein - zwei
    /// verschiedene Nummern sind dann zwei Eintraege.
    @Test("zwei Personen bleiben zwei Eintraege")
    func twoPeopleStayTwo() throws {
        let (archive, _) = try makeArchive()
        _ = archive.add(Sample.record(Sample.chipData(codiceFiscale: "AAAAAA00A00A000A")))
        let after = archive.add(
            Sample.record(
                Sample.chipData(surname: "RAAB", documentNumber: "CA55555CD",
                                codiceFiscale: "BBBBBB00B00B000B")
            )
        )
        #expect(after.count == 2)
    }

    @Test("abgelaufene Eintraege verschwinden beim Lesen")
    func expiredRecordsVanish() throws {
        let (archive, _) = try makeArchive()
        let old = currentTimeMillis() - Int64(DocumentArchive.retentionDays + 1) * 86_400_000
        _ = archive.add(Sample.record(Sample.chipData(), storedAt: old))
        #expect(archive.load().isEmpty)
    }

    /// Eine zurueckgestellte Uhr darf nicht dazu fuehren, dass etwas ewig liegen
    /// bleibt.
    @Test("ein Eintrag aus der Zukunft gilt als abgelaufen")
    func futureRecordCountsAsExpired() throws {
        let (archive, _) = try makeArchive()
        _ = archive.add(Sample.record(Sample.chipData(), storedAt: currentTimeMillis() + 86_400_000))
        #expect(archive.load().isEmpty)
    }

    @Test("Loeschen entfernt genau den benannten Eintrag")
    func removeById() throws {
        let (archive, _) = try makeArchive()
        let first = Sample.record(Sample.chipData(codiceFiscale: "AAAAAA00A00A000A"),
                                  storedAt: earlier)
        let second = Sample.record(
            Sample.chipData(documentNumber: "CA55555CD", codiceFiscale: "BBBBBB00B00B000B"),
            storedAt: later
        )
        _ = archive.add(first)
        _ = archive.add(second)

        let after = archive.remove(ids: [first.id])
        #expect(after.map(\.id) == [second.id])
    }

    /// Ein Fehler beim Entschluesseln heisst, dass der Inhalt selbst nicht mehr zu
    /// retten ist - dann, und nur dann, wird aufgeraeumt.
    @Test("Datenmuell wird verworfen, nicht behalten")
    func garbageIsCleared() throws {
        let (archive, file) = try makeArchive()
        _ = archive.add(Sample.record(Sample.chipData()))
        try Data(repeating: 0x41, count: 64).write(to: file)

        var notes: [String] = []
        archive.log = { notes.append($0) }
        #expect(archive.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(notes.contains { $0.hasPrefix("Entschluesseln") })
    }

    @Test("die Restlaufzeit wird aufgerundet")
    func remainingDaysRoundsUp() throws {
        let (archive, _) = try makeArchive()
        #expect(archive.remainingDays(storedAt: currentTimeMillis()) == DocumentArchive.retentionDays)
        let old = currentTimeMillis() - Int64(DocumentArchive.retentionDays) * 86_400_000
        #expect(archive.remainingDays(storedAt: old) == 0)
    }
}
