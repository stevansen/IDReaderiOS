import Foundation
import CryptoKit

/// Wer ein Zertifikat ausgestellt hat, und mit welcher Nummer.
///
/// Genau das, was eine Sperrpruefung braucht, und nichts darueber hinaus: eine
/// Sperrliste sagt „diese Nummern dieses Ausstellers gelten nicht mehr". Ohne
/// beides ist die Antwort nicht zu bilden, mit mehr wird sie nicht besser.
///
/// ## Warum das gespeichert wird
///
/// Der Datensatz muss die Pruefung **spaeter** nachholen koennen, und dann ist
/// das Dokument laengst aus der Hand. Also merkt er sich diese zwei Angaben. Sie
/// sagen nichts ueber die Person: die Seriennummer gehoert dem Signierer, der
/// zehntausende Dokumente signiert, nicht dem Dokument. Der Ausstellername wird
/// als Abdruck gespeichert - ihn im Klartext zu halten, brachte nichts, was der
/// Vergleich nicht auch ueber den Abdruck kann.
public struct CertificateIdentity: Sendable, Equatable, Hashable {

    /// Die Seriennummer als Grossbuchstaben-Hex ohne fuehrende Nullen.
    public let serialHex: String

    /// Die Bytes des Ausstellernamens, wie sie im Zertifikat stehen.
    ///
    /// Als Bytes und nicht als Text - siehe ``DER``.
    public let issuerDER: [UInt8]

    public init(serialHex: String, issuerDER: [UInt8]) {
        self.serialHex = serialHex
        self.issuerDER = issuerDER
    }

    /// SHA-256 ueber die Bytes des Ausstellernamens, als Hex.
    public var issuerDigest: String { Self.digest(of: issuerDER) }

    static func digest(of bytes: [UInt8]) -> String {
        SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Liest die Angaben aus einem X.509-Zertifikat.
public enum CertificateReader {

    /// Ausstellername und Seriennummer aus einem Zertifikat in DER.
    ///
    /// ```
    /// Certificate  ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signature }
    /// TBSCertificate ::= SEQUENCE {
    ///     version         [0] EXPLICIT INTEGER DEFAULT v1,
    ///     serialNumber        INTEGER,
    ///     signature           AlgorithmIdentifier,
    ///     issuer              Name,
    ///     ... }
    /// ```
    ///
    /// Die Fassung ist freigestellt. Steht sie da, traegt sie `[0]`; steht sie
    /// nicht da, ist das erste Element schon die Seriennummer. Beide Faelle
    /// kommen vor, und der zweite ist bei alten Zertifikaten der Normalfall.
    public static func identity(ofCertificate der: [UInt8]) throws -> CertificateIdentity {
        var outer = DER.Cursor(der)
        let certificate = try outer.next(expecting: DER.sequence)
        var body = DER.into(certificate)
        let tbs = try body.next(expecting: DER.sequence)

        var fields = DER.into(tbs)
        var element = try fields.next()
        if element.contextTagNumber == 0 {
            element = try fields.next()
        }
        let serial = try DER.integerHex(element)
        _ = try fields.next(expecting: DER.sequence)  // signature AlgorithmIdentifier
        let issuer = try fields.next()
        guard issuer.tag == DER.sequence else {
            throw DER.Failure.unexpectedTag(issuer.tag)
        }
        return CertificateIdentity(serialHex: serial, issuerDER: issuer.encoded)
    }

    /// Der Subjektname eines Zertifikats, als Bytes.
    ///
    /// Braucht die Zuordnung in die andere Richtung: welches der hinterlegten
    /// CSCA-Zertifikate gehoert zu dieser Sperrliste? Antwort ist das, dessen
    /// Subjekt gleich dem Aussteller der Liste ist.
    public static func subject(ofCertificate der: [UInt8]) throws -> [UInt8] {
        var outer = DER.Cursor(der)
        let certificate = try outer.next(expecting: DER.sequence)
        var body = DER.into(certificate)
        let tbs = try body.next(expecting: DER.sequence)

        var fields = DER.into(tbs)
        var element = try fields.next()
        if element.contextTagNumber == 0 {
            element = try fields.next()
        }
        _ = element                                    // serialNumber
        _ = try fields.next(expecting: DER.sequence)   // signature
        _ = try fields.next(expecting: DER.sequence)   // issuer
        _ = try fields.next(expecting: DER.sequence)   // validity
        let subject = try fields.next(expecting: DER.sequence)
        return subject.encoded
    }

    /// Die Verteilstellen der Sperrliste, wie das Zertifikat sie nennt.
    ///
    /// ## Warum aus dem Zertifikat und nicht aus einer Konstante
    ///
    /// Eine fest eingetragene Adresse ist eine Behauptung ueber eine fremde
    /// Behoerde. Die Zertifikate sagen es selbst, und wenn sich das aendert,
    /// aendert es sich mit dem naechsten Auffrischen des Vertrauensspeichers -
    /// ohne dass jemand daran denken muss.
    ///
    /// ```
    /// CRLDistributionPoints ::= SEQUENCE OF DistributionPoint
    /// DistributionPoint ::= SEQUENCE {
    ///     distributionPoint [0] DistributionPointName OPTIONAL, ... }
    /// DistributionPointName ::= CHOICE { fullName [0] GeneralNames, ... }
    /// GeneralName ::= CHOICE { ... uniformResourceIdentifier [6] IA5String ... }
    /// ```
    ///
    /// **`http` wird zu `https` gehoben.** Zwei der italienischen Zertifikate von
    /// 2016 nennen die Adresse ohne Verschluesselung, die vier von 2020 und 2024
    /// dieselbe mit. Derselbe Rechner also - und dann ist die Wahl zwischen einer
    /// Ausnahme in der Transportsicherheit der App und einem Buchstaben mehr in
    /// der Adresse keine Wahl. Dass die Liste selbst signiert ist und ohnehin
    /// geprueft wird, macht die unverschluesselte Abholung nicht besser: sie
    /// verraet einem Mitlesenden, wer die App benutzt.
    public static func crlDistributionPoints(
        ofCertificate der: [UInt8]
    ) -> [String] {
        guard let extensions = try? extensionsElement(ofCertificate: der) else { return [] }
        var cursor = DER.into(extensions)
        guard let list = try? cursor.next(expecting: DER.sequence) else { return [] }

        var found: [String] = []
        var entries = DER.into(list)
        while let entry = try? entries.next(expecting: DER.sequence) {
            var fields = DER.into(entry)
            guard let oidElement = try? fields.next(expecting: DER.objectIdentifier),
                  let oid = try? DER.oid(oidElement), oid == "2.5.29.31"
            else { continue }
            // Das kritisch-Kennzeichen ist freigestellt; danach kommt der Wert.
            var value: DER.Element?
            while let next = try? fields.next() {
                if next.tag == DER.octetString { value = next }
            }
            guard let value else { continue }
            found.append(contentsOf: uris(inDistributionPoints: value.content))
        }
        return found
    }

    private static func uris(inDistributionPoints der: [UInt8]) -> [String] {
        var cursor = DER.Cursor(der)
        guard let points = try? cursor.next(expecting: DER.sequence) else { return [] }
        var result: [String] = []
        var entries = DER.into(points)
        while let point = try? entries.next(expecting: DER.sequence) {
            var fields = DER.into(point)
            while let field = try? fields.next() {
                guard field.contextTagNumber == 0 else { continue }
                var names = DER.Cursor(field.content)
                while let name = try? names.next() {
                    guard name.contextTagNumber == 0 else { continue }
                    var general = DER.Cursor(name.content)
                    while let entry = try? general.next() {
                        // uniformResourceIdentifier [6], primitiv: 0x86.
                        guard entry.contextTagNumber == 6,
                              let text = String(bytes: entry.content, encoding: .ascii)
                        else { continue }
                        result.append(secured(text))
                    }
                }
            }
        }
        return result
    }

    private static func secured(_ url: String) -> String {
        guard url.lowercased().hasPrefix("http://") else { return url }
        return "https://" + url.dropFirst("http://".count)
    }

    /// Das Feld `extensions [3]` eines Zertifikats.
    private static func extensionsElement(
        ofCertificate der: [UInt8]
    ) throws -> DER.Element {
        var outer = DER.Cursor(der)
        let certificate = try outer.next(expecting: DER.sequence)
        var body = DER.into(certificate)
        let tbs = try body.next(expecting: DER.sequence)

        var fields = DER.into(tbs)
        var element = try fields.next()
        if element.contextTagNumber == 0 { element = try fields.next() }
        _ = try fields.next(expecting: DER.sequence)   // signature
        _ = try fields.next(expecting: DER.sequence)   // issuer
        _ = try fields.next(expecting: DER.sequence)   // validity
        _ = try fields.next(expecting: DER.sequence)   // subject
        _ = try fields.next(expecting: DER.sequence)   // subjectPublicKeyInfo

        // Danach nur noch Freigestelltes: [1], [2] und die Erweiterungen als [3].
        while let next = try? fields.next() {
            if next.contextTagNumber == 3 { return next }
        }
        throw DER.Failure.notFound("keine Erweiterungen")
    }

    /// Dasselbe aus einem PEM-Text.
    ///
    /// Die mitgelieferte Lesebibliothek gibt das Dokumentsignierer-Zertifikat als
    /// PEM heraus; das ist die einzige ihrer Ausgaben, die vollstaendig ist. Ihre
    /// eigene `getSerialNumber()` laeuft ueber `ASN1_INTEGER_get` und damit bei
    /// langen Seriennummern ueber.
    public static func identity(ofPEM pem: String) throws -> CertificateIdentity {
        try identity(ofCertificate: der(fromPEM: pem))
    }

    /// Die DER-Bytes aus einem PEM-Block.
    public static func der(fromPEM pem: String) throws -> [UInt8] {
        let body = pem
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        guard let data = Data(base64Encoded: body, options: .ignoreUnknownCharacters) else {
            throw DER.Failure.notFound("PEM ohne lesbaren Inhalt")
        }
        return [UInt8](data)
    }
}
