#if DEBUG
import Foundation
import IDReaderCore

/// Erfundene Datensätze, ausschließlich für Bildschirmfotos.
///
/// ## Warum das hier überhaupt steht
///
/// Ergebnis, Archiv und Teilen zeigen ohne Daten nichts, und im Simulator gibt es
/// kein NFC. Für die Bilder im Store braucht es also einen Weg, das Archiv zu
/// füllen, ohne eine Karte in der Hand zu haben.
///
/// ## Und warum das gefährlich wäre, wenn es anders gebaut wäre
///
/// Ein Weg, der in einer App zum Lesen von Ausweisen Daten **erfindet**, ist
/// genau das, was es nicht geben darf. Deshalb drei Riegel, und alle drei
/// zusammen:
///
/// 1. Die ganze Datei liegt in `#if DEBUG`. Im Auslieferungsbau existiert sie
///    nicht — nicht abgeschaltet, sondern nicht vorhanden.
/// 2. Sie läuft nur, wenn beim Start ausdrücklich `IDREADER_DEMO=1` gesetzt ist.
///    Auch im Debug-Bau passiert ohne diese Umgebung nichts.
/// 3. Die Werte sind erkennbar erfunden — dieselben Namen wie im Prüfkorpus, der
///    aus demselben Grund anonymisiert ist.
///
/// Wer diese Riegel lockert, macht aus einem Werkzeug für Bildschirmfotos einen
/// Weg, Ausweisdaten zu fälschen.
enum DemoData {

    /// Ob dieser Start Beispieldaten anlegen soll.
    ///
    /// Zwei Wege, weil der eine nicht immer ankommt: eine Umgebungsvariable
    /// (`SIMCTL_CHILD_IDREADER_DEMO=1` beim Start ueber `simctl`) oder ein
    /// Startargument (`-IDREADER_DEMO 1`), das `UserDefaults` von sich aus
    /// aufnimmt. Das zweite ist der verlaesslichere.
    static var isRequested: Bool {
        if ProcessInfo.processInfo.environment["IDREADER_DEMO"] == "1" { return true }
        return UserDefaults.standard.bool(forKey: "IDREADER_DEMO")
    }

    /// Ein Archiv mit Beispieldatensätzen.
    ///
    /// Mit einem Schlüssel im Arbeitsspeicher und nicht aus dem Schlüsselbund:
    /// eine unsigniert in den Simulator geschobene App hat keine Berechtigung
    /// dafür, `SecItemAdd` scheitert mit `errSecMissingEntitlement`, und das
    /// Archiv bliebe leer. Für Bildschirmfotos ist ein flüchtiger Schlüssel
    /// ohnehin das Richtige — nach dem Beenden ist nichts mehr da.
    static func archive() -> DocumentArchive {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("demo-archive.bin")
        try? FileManager.default.removeItem(at: file)

        let archive = DocumentArchive(file: file, keys: InMemoryArchiveKeyStore())
        archive.log = { print("[demo-archive] \($0)") }
        for record in records(now: currentTimeMillis()) {
            _ = archive.add(record)
        }
        return archive
    }

    private static func records(now: Int64) -> [StoredDocument] {
        [
            StoredDocument(
                data: card,
                // Heute, vor einer Stunde - damit die Tagesgruppe „Heute" heißt.
                storedAt: now - 3_600_000,
                cardId: nil,
                can: "482913",
                // Geprüft: so sieht der Regelfall aus.
                signer: SignerReference(
                    serialHex: "4A1F0B", issuerDigest: "demo-issuer"
                ),
                revocation: RevocationCheck(
                    outcome: .notRevoked,
                    checkedAt: Date().addingTimeInterval(-3_600),
                    listIssuedAt: Date().addingTimeInterval(-6 * 86_400),
                    listExpiresAt: Date().addingTimeInterval(24 * 86_400)
                )
            ),
            StoredDocument(
                data: passport,
                storedAt: now - 7_200_000,
                cardId: nil,
                can: "",
                // Offen: gelesen, als keine Liste vorlag. Der Fall, um den es bei
                // der Sperrprüfung eigentlich geht.
                signer: SignerReference(
                    serialHex: "7C22D9", issuerDigest: "demo-issuer-2"
                )
            ),
            StoredDocument(
                data: licence,
                // Gestern, damit die zweite Tagesgruppe im Archiv sichtbar wird.
                storedAt: now - 93_600_000,
                cardId: nil,
                can: ""
            ),
        ]
    }

    // -----------------------------------------------------------------------

    /// Eine Identitätskarte, Prüfung aufgegangen.
    private static var card: DocumentData {
        DocumentData(
            provenance: .chip,
            surname: "MUSTERMANN",
            givenNames: "ANITA",
            dateOfBirth: "07.04.1968",
            gender: .female,
            nationality: "ITA",
            issuingState: "ITA",
            documentNumber: "CA12345AB",
            documentCode: "ID",
            dateOfExpiry: "07.04.2031",
            // Zweisprachig, wie es in Südtirol auf der Karte steht - damit auf dem
            // Bild zu sehen ist, dass die App eine Hälfte wählt.
            placeOfBirth: "BOLZANO/BOZEN, BZ",
            residence: "VIA C.AUGUSTA/C.-AUGUSTA-STR., 16/B, BOLZANO/BOZEN, BZ",
            codiceFiscale: "MSTNTA68D47A952K",
            issuingAuthority: "MINISTERO DELL'INTERNO",
            dateOfIssue: "05.03.2019",
            photo: nil,
            authenticity: Authenticity(
                status: .verified,
                dataGroupsIntact: true,
                signatureValid: true,
                chainTrusted: true,
                chipAuthenticationExpected: true,
                chipAuthenticated: true,
                checkedDataGroups: [1, 11, 12, 14],
                signerName: "Italian Document Signer 07",
                trustAnchorName: "Italy Country Signing CA",
                digestAlgorithm: "SHA256"
            )
        )
    }

    /// Ein Reisepass - andere Farbwelt, andere Felder.
    private static var passport: DocumentData {
        DocumentData(
            provenance: .chip,
            surname: "RAAB",
            givenNames: "SEBASTIAN",
            dateOfBirth: "02.09.1965",
            gender: .male,
            nationality: "ITA",
            issuingState: "ITA",
            documentNumber: "YA1234567",
            documentCode: "P",
            dateOfExpiry: "02.09.2033",
            placeOfBirth: "MERANO/MERAN, BZ",
            codiceFiscale: "RBSBST65P02A952X",
            issuingAuthority: "MINISTERO DEGLI AFFARI ESTERI",
            dateOfIssue: "03.09.2023",
            photo: nil,
            authenticity: Authenticity(
                status: .verified,
                dataGroupsIntact: true,
                signatureValid: true,
                chainTrusted: true,
                chipAuthenticationExpected: true,
                chipAuthenticated: true,
                checkedDataGroups: [1, 11, 12, 14],
                signerName: "Italian Document Signer 07",
                trustAnchorName: "Italy Country Signing CA",
                digestAlgorithm: "SHA256"
            )
        )
    }

    /// Eine Fahrerlaubnis - kein Siegel, sondern der Vorbehalt. Genau der
    /// Unterschied, den ein Bild im Store zeigen soll.
    private static var licence: DocumentData {
        var input = LicenceInput()
        input.surname = "DI STEFANO"
        input.givenNames = "GIUSEPPE"
        input.dateOfBirth = "21.07.1976"
        input.placeOfBirth = "TRENTO (TN)"
        input.dateOfIssue = "12.03.2019"
        input.dateOfExpiry = "21.07.2029"
        input.number = "TN1234567A"
        input.categories = "AM B"
        return input.toDocumentData()
    }
}
#endif
