import Foundation
import Testing

@testable import IDReaderCore

/// Die Pruefstelle aus `Fixtures/`.
///
/// Selbst erzeugt, mit einer Sperrliste, auf der genau ein Signierer steht. Sie
/// steht fuer den Weg durch Leser, Signaturpruefung und Ablage - nicht fuer die
/// italienische Wirklichkeit.
enum TestAuthority {

    static func fixture(_ name: String) -> Data {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "der", subdirectory: "Fixtures"
        ), let data = try? Data(contentsOf: url) else {
            fatalError("Pruefdatei \(name).der fehlt")
        }
        return data
    }

    static var csca: Data { fixture("test-csca") }
    static var crl: Data { fixture("test-crl") }
    static var revokedSigner: Data { fixture("test-signer-revoked") }
    static var goodSigner: Data { fixture("test-signer-good") }

    static func store(log: (@Sendable (String) -> Void)? = nil) -> RevocationStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("revocation-\(UUID().uuidString)")
        return RevocationStore(
            directory: directory,
            trustedCertificates: [csca],
            log: log
        )
    }
}

@Suite("DER")
struct DERTests {

    @Test("eine Seriennummer laenger als acht Byte bleibt vollstaendig")
    func longSerial() throws {
        // Zwanzig Byte, wie sie ein Dokumentsignierer wirklich traegt. Ueber
        // `ASN1_INTEGER_get` waere hier -1 herausgekommen.
        let bytes: [UInt8] = [0x02, 0x14] + (1 ... 20).map { UInt8($0) }
        var cursor = DER.Cursor(bytes)
        let element = try cursor.next()
        #expect(try DER.integerHex(element) == "0102030405060708090A0B0C0D0E0F1011121314")
    }

    @Test("fuehrende Nullen fallen weg, die Zahl bleibt gleich")
    func leadingZero() throws {
        // Ein positives INTEGER, dessen oberstes Bit gesetzt ist, traegt in DER
        // eine fuehrende Null. Zwei Schreibweisen derselben Nummer duerfen nicht
        // zu zwei verschiedenen Zeichenketten fuehren.
        var padded = DER.Cursor([0x02, 0x02, 0x00, 0x80])
        var bare = DER.Cursor([0x02, 0x01, 0x80])
        #expect(try DER.integerHex(try padded.next()) == "80")
        #expect(try DER.integerHex(try bare.next()) == "80")
    }

    @Test("eine unbestimmte Laenge wird abgewiesen")
    func indefiniteLength() {
        var cursor = DER.Cursor([0x30, 0x80, 0x00, 0x00])
        #expect(throws: DER.Failure.indefiniteLength) { try cursor.next() }
    }

    @Test("eine Laenge, die ueber das Ende hinausweist, wird abgewiesen")
    func truncated() {
        var cursor = DER.Cursor([0x04, 0x10, 0x01, 0x02])
        #expect(throws: DER.Failure.truncated) { try cursor.next() }
    }

    @Test("UTCTime wird nach RFC 5280 ins Jahrhundert gesetzt")
    func utcTimeCentury() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func year(of text: String) throws -> Int {
            let bytes = [UInt8](text.utf8)
            var cursor = DER.Cursor([DER.utcTime, UInt8(bytes.count)] + bytes)
            return calendar.component(.year, from: try DER.time(try cursor.next()))
        }
        #expect(try year(of: "260821175736Z") == 2026)
        #expect(try year(of: "490101000000Z") == 2049)
        #expect(try year(of: "500101000000Z") == 1950)
        #expect(try year(of: "990101000000Z") == 1999)
    }
}

@Suite("Zertifikat lesen")
struct CertificateReaderTests {

    @Test("Seriennummer und Aussteller kommen heraus")
    func identity() throws {
        let signer = try CertificateReader.identity(
            ofCertificate: [UInt8](TestAuthority.revokedSigner)
        )
        #expect(signer.serialHex == "1000")

        // Der Aussteller des Signierers muss das Subjekt der Pruefstelle sein -
        // sonst waere die Zuordnung Liste-zu-Signierer nicht zu bilden.
        let subject = try CertificateReader.subject(
            ofCertificate: [UInt8](TestAuthority.csca)
        )
        #expect(signer.issuerDER == subject)
    }

    @Test("PEM und DER ergeben dieselbe Angabe")
    func pemMatchesDER() throws {
        // Die Lesebibliothek gibt das Signiererzertifikat als PEM heraus; beide
        // Wege muessen zum gleichen Ergebnis kommen.
        let der = [UInt8](TestAuthority.goodSigner)
        let base64 = TestAuthority.goodSigner.base64EncodedString()
        let pem = "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
        #expect(
            try CertificateReader.identity(ofPEM: pem)
                == CertificateReader.identity(ofCertificate: der)
        )
    }
}

@Suite("Sperrliste lesen")
struct RevocationListTests {

    @Test("die gesperrte Nummer steht drauf, die andere nicht")
    func serials() throws {
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        #expect(list.revokes("1000"))
        #expect(!list.revokes("1001"))
    }

    @Test("Ausgabe- und Ablaufdatum werden gelesen")
    func dates() throws {
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        let nextUpdate = try #require(list.nextUpdate)
        #expect(nextUpdate > list.thisUpdate)
        // Die Pruefliste laeuft dreissig Tage.
        #expect(nextUpdate.timeIntervalSince(list.thisUpdate) == 30 * 24 * 3600)
        #expect(list.isCurrent(at: list.thisUpdate))
        #expect(!list.isCurrent(at: nextUpdate.addingTimeInterval(1)))
    }

    @Test("der Aussteller der Liste ist das Subjekt der Pruefstelle")
    func issuerMatchesAuthority() throws {
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        let subject = try CertificateReader.subject(
            ofCertificate: [UInt8](TestAuthority.csca)
        )
        #expect(list.issuerDER == subject)
    }

    @Test("das signierte Stueck ist die Kodierung von tbsCertList")
    func signedBytesAreTheTBS() throws {
        let der = [UInt8](TestAuthority.crl)
        let list = try RevocationList.parse(der)
        // Es muss ein SEQUENCE sein und ein echtes Teilstueck der Datei - sonst
        // prueft die Signaturpruefung etwas anderes als das Unterschriebene.
        #expect(list.signedBytes.first == DER.sequence)
        #expect(list.signedBytes.count < der.count)
    }
}

@Suite("Sperrliste pruefen")
struct RevocationListVerifierTests {

    @Test("die echte Liste besteht die Pruefung gegen ihre Pruefstelle")
    func good() throws {
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        #expect(RevocationListVerifier.verify(list, against: [TestAuthority.csca]) == nil)
    }

    @Test("eine verfaelschte Signatur fliegt auf")
    func tampered() throws {
        var bytes = [UInt8](TestAuthority.crl)
        // Das letzte Byte gehoert zur Signatur.
        bytes[bytes.count - 1] ^= 0xFF
        let list = try RevocationList.parse(bytes)
        #expect(
            RevocationListVerifier.verify(list, against: [TestAuthority.csca]) == .badSignature
        )
    }

    @Test("eine Liste eines fremden Ausstellers wird nicht angenommen")
    func foreignIssuer() throws {
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        // Gegen die echten italienischen Anker geprueft: die Pruefstelle der
        // Tests steht dort nicht, und das Ergebnis darf nicht „Signatur falsch"
        // heissen, sondern „kein passender Aussteller".
        #expect(
            RevocationListVerifier.verify(list, against: CscaTrustStore.load())
                == .noMatchingAuthority
        )
    }

    @Test("PSS mit SHA-256 wird erkannt, PSS mit fremder Salzlaenge abgelehnt")
    func pssParameters() {
        // hashAlgorithm [0] { sha256, NULL }, saltLength [2] 32
        let sha256: [UInt8] = [
            0xA0, 0x0D, 0x30, 0x0B, 0x06, 0x09,
            0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00,
        ]
        let salt32: [UInt8] = [0xA2, 0x03, 0x02, 0x01, 0x20]
        let salt20: [UInt8] = [0xA2, 0x03, 0x02, 0x01, 0x14]

        func parameters(_ fields: [UInt8]) -> [UInt8] {
            [0x30, UInt8(fields.count)] + fields
        }
        #expect(
            RevocationListVerifier.pssAlgorithm(parameters: parameters(sha256 + salt32))
                == .success(.rsaSignatureMessagePSSSHA256)
        )
        // Nicht „Signatur falsch": eine Salzlaenge, die `Security` nicht kann,
        // ist ein Nichtkoennen und kein Verdacht.
        #expect(
            RevocationListVerifier.pssAlgorithm(parameters: parameters(sha256 + salt20))
                == .failure(.unsupportedAlgorithm("PSS mit Salzlaenge 20"))
        )
    }
}

@Suite("Sperrlisten-Ablage")
struct RevocationStoreTests {

    @Test("eine geprüfte Liste wird aufgenommen, eine verfaelschte nicht")
    func acceptance() throws {
        let store = TestAuthority.store()
        #expect(store.isEmpty)

        #expect(store.accept(der: TestAuthority.crl) == nil)
        #expect(!store.isEmpty)

        var bytes = [UInt8](TestAuthority.crl)
        bytes[bytes.count - 1] ^= 0xFF
        #expect(store.accept(der: Data(bytes)) == .untrusted(.badSignature))
    }

    @Test("kein Bestand heisst offen und nicht ungesperrt")
    func nothingYet() throws {
        let store = TestAuthority.store()
        let signer = SignerReference(
            try CertificateReader.identity(ofCertificate: [UInt8](TestAuthority.goodSigner))
        )
        // Das ist der Kern der ganzen Sache: ohne Liste gibt es kein Ergebnis,
        // und „kein Ergebnis" darf nie wie „nicht gesperrt" aussehen.
        #expect(store.evaluate(signer) == nil)
    }

    @Test("mit Liste kommt fuer beide Signierer das richtige Urteil")
    func verdicts() throws {
        let store = TestAuthority.store()
        store.accept(der: TestAuthority.crl)

        let revoked = SignerReference(
            try CertificateReader.identity(ofCertificate: [UInt8](TestAuthority.revokedSigner))
        )
        let good = SignerReference(
            try CertificateReader.identity(ofCertificate: [UInt8](TestAuthority.goodSigner))
        )
        #expect(store.evaluate(revoked)?.outcome == .revoked)
        #expect(store.evaluate(good)?.outcome == .notRevoked)

        // Das Ausgabedatum der Liste muss im Datensatz landen, nicht nur der
        // Zeitpunkt der Pruefung.
        let list = try RevocationList.parse([UInt8](TestAuthority.crl))
        #expect(store.evaluate(good)?.listIssuedAt == list.thisUpdate)
        #expect(store.newestListIssuedAt == list.thisUpdate)
    }

    @Test("ein Signierer eines anderen Ausstellers ist ein Ergebnis")
    func otherIssuer() throws {
        let store = TestAuthority.store()
        store.accept(der: TestAuthority.crl)
        let stranger = SignerReference(serialHex: "1000", issuerDigest: "unbekannt")
        #expect(store.evaluate(stranger)?.outcome == .noListForIssuer)
    }

    @Test("die Ablage uebersteht einen Neustart")
    func survivesRestart() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("revocation-\(UUID().uuidString)")
        let first = RevocationStore(
            directory: directory, trustedCertificates: [TestAuthority.csca]
        )
        first.accept(der: TestAuthority.crl)

        // Genau das ist der Sinn der Ablage: der Abgleich braucht danach kein
        // Netz mehr, auch nicht nach einem Neustart.
        let second = RevocationStore(
            directory: directory, trustedCertificates: [TestAuthority.csca]
        )
        let revoked = SignerReference(
            try CertificateReader.identity(ofCertificate: [UInt8](TestAuthority.revokedSigner))
        )
        #expect(second.evaluate(revoked)?.outcome == .revoked)
    }
}

@Suite("Wann nachgeholt wird")
struct RevocationRetryTests {

    private func check(
        _ outcome: RevocationOutcome,
        listIssuedAt: Date,
        expires: Date? = nil
    ) -> RevocationCheck {
        RevocationCheck(
            outcome: outcome,
            checkedAt: listIssuedAt,
            listIssuedAt: listIssuedAt,
            listExpiresAt: expires
        )
    }

    @Test("eine neuere Liste ist ein Grund, noch einmal zu pruefen")
    func newerList() {
        let older = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let newer = older.addingTimeInterval(86_400)
        #expect(check(.notRevoked, listIssuedAt: older).deservesRetry(withListIssuedAt: newer))
        #expect(!check(.notRevoked, listIssuedAt: newer).deservesRetry(withListIssuedAt: older))
    }

    @Test("eine Sperre wird nicht zurueckgenommen")
    func revokedStays() {
        let older = Date(timeIntervalSinceReferenceDate: 1_000_000)
        // Steht ein Signierer einmal auf der Liste, wird er nicht durch eine
        // spaetere Liste wieder gut. Ein erneuter Durchgang koennte das aber
        // aussehen lassen, wenn eine Liste unvollstaendig ist - also gar nicht
        // erst fragen.
        #expect(
            !check(.revoked, listIssuedAt: older)
                .deservesRetry(withListIssuedAt: older.addingTimeInterval(86_400))
        )
    }

    @Test("eine ueberholte Liste wird als solche erkannt")
    func staleList() {
        let issued = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let expires = issued.addingTimeInterval(30 * 86_400)
        let entry = check(.notRevoked, listIssuedAt: issued, expires: expires)
        #expect(!entry.usedStaleList(at: issued.addingTimeInterval(86_400)))
        #expect(entry.usedStaleList(at: expires.addingTimeInterval(1)))
    }
}

@Suite("Sperrpruefung nachholen")
struct RevocationCatchUpTests {

    private func makeArchive() throws -> DocumentArchive {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("idreader-crl-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return DocumentArchive(
            file: directory.appendingPathComponent("archive.bin"),
            keys: InMemoryArchiveKeyStore()
        )
    }

    private func record(signer: SignerReference?) -> StoredDocument {
        var document = Sample.record(Sample.chipData())
        document.signer = signer
        return document
    }

    private func signer(_ certificate: Data) throws -> SignerReference {
        SignerReference(try CertificateReader.identity(ofCertificate: [UInt8](certificate)))
    }

    /// **Der Test, um den es hier eigentlich geht.**
    ///
    /// Gelesen ohne Netz, geprueft mit. Ginge das nicht, waere die ganze
    /// Sperrpruefung auf die Faelle beschraenkt, in denen gerade Empfang ist -
    /// also auf die, in denen sie am wenigsten gebraucht wird.
    @Test("was ohne Liste gelesen wurde, wird mit Liste nachgeprueft")
    func caughtUpLater() throws {
        let archive = try makeArchive()
        let store = TestAuthority.store()

        // Lesen ohne Netz: es liegt keine Liste vor, die Pruefung bleibt offen.
        var stored = archive.add(record(signer: try signer(TestAuthority.revokedSigner)))
        #expect(stored.first?.revocation == nil)
        #expect(stored.first?.revocationPending == true)
        #expect(archive.pendingRevocationCount() == 1)

        // Die Liste kommt an - und der alte Eintrag bekommt sein Urteil.
        store.accept(der: TestAuthority.crl)
        stored = archive.catchUpRevocation(using: store)
        #expect(stored.first?.revocation?.outcome == .revoked)
        #expect(stored.first?.revocationPending == false)
        #expect(archive.pendingRevocationCount() == 0)
    }

    @Test("ohne Signierer wird nichts angekuendigt")
    func noSignerNoPromise() throws {
        let archive = try makeArchive()
        let store = TestAuthority.store()
        store.accept(der: TestAuthority.crl)

        // Eine Fahrerlaubnis aus einem Foto hat keinen Signierer. „Pruefung steht
        // aus" waere hier eine Ankuendigung, die nie eingeloest wird.
        let stored = archive.add(record(signer: nil))
        #expect(stored.first?.revocationPending == false)
        #expect(archive.catchUpRevocation(using: store).first?.revocation == nil)
    }

    @Test("ein zweiter Durchgang ohne neue Liste aendert nichts")
    func idempotent() throws {
        let archive = try makeArchive()
        let store = TestAuthority.store()
        store.accept(der: TestAuthority.crl)
        archive.add(record(signer: try signer(TestAuthority.goodSigner)))

        let first = archive.catchUpRevocation(using: store)
        let second = archive.catchUpRevocation(using: store)
        #expect(first == second)
        #expect(first.first?.revocation?.outcome == .notRevoked)
    }

    @Test("das Urteil uebersteht Speichern und Laden")
    func survivesRoundTrip() throws {
        let archive = try makeArchive()
        let store = TestAuthority.store()
        store.accept(der: TestAuthority.crl)
        archive.add(record(signer: try signer(TestAuthority.revokedSigner)))
        let updated = archive.catchUpRevocation(using: store)

        // Ueber die Datei hinweg: sonst stuende beim naechsten Start wieder
        // „offen", und die Pruefung liefe bei jedem Start neu.
        #expect(archive.load() == updated)
        let check = try #require(archive.load().first?.revocation)
        #expect(check.outcome == .revoked)
    }
}

@Suite("Verteilstellen")
struct DistributionPointTests {

    @Test("die hinterlegten italienischen Zertifikate nennen eine Adresse")
    func italianCertificates() {
        let certificates = CscaTrustStore.load()
        #expect(certificates.count == 9)

        let points = certificates.flatMap {
            CertificateReader.crlDistributionPoints(ofCertificate: [UInt8]($0))
        }
        // Sechs von neun nennen eine Verteilstelle, und alle dieselbe. Die
        // uebrigen drei nennen keine - wer von einem von ihnen signiert wurde,
        // ist nicht zu pruefen, und das gehoert gesagt statt verschwiegen.
        #expect(points.count == 6)
        #expect(
            Set(points)
                == ["https://csca-ita.interno.gov.it/certificatiCSCA/CRL_CSCA.crl"]
        )
    }

    @Test("http wird zu https gehoben")
    func upgradedToTLS() {
        // Zwei der sechs stehen im Zertifikat ohne Verschluesselung. Dieselbe
        // Adresse liefert die vier neueren mit - also wird sie so abgerufen.
        let raw = CscaTrustStore.load().flatMap {
            CertificateReader.crlDistributionPoints(ofCertificate: [UInt8]($0))
        }
        #expect(!raw.contains { $0.hasPrefix("http://") })
    }
}
