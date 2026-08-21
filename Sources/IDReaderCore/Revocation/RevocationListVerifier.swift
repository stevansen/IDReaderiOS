import Foundation
import Security

/// Prueft die Signatur einer Sperrliste gegen die hinterlegten CSCA-Zertifikate.
///
/// ## Warum das nicht weggelassen werden darf
///
/// Eine ungeprueft uebernommene Sperrliste ist schlimmer als keine. Wer den
/// Netzverkehr in der Hand hat, koennte eine leere Liste unterschieben und damit
/// jedem gesperrten Signierer wieder ein gruenes Siegel verschaffen - und die App
/// wuerde dazu „geprueft am, Liste vom" anzeigen, also eine Zusage geben, die sie
/// nicht halten kann. Deshalb wird jede geladene Liste gegen dieselben neun
/// Zertifikate geprueft, die auch die Passive Authentication verankern, und eine
/// Liste ohne gueltige Signatur wird verworfen und nicht gespeichert.
///
/// ## Mit den Mitteln des Systems
///
/// `Security` und nicht OpenSSL: das Verfahren ist RSA - PKCS#1 v1.5 bei den
/// alten Zertifikaten, PSS bei denen ab 2020 -, und beides kann
/// `SecKeyVerifySignature`. Damit bleibt die Pruefung im Paket und laeuft im Test
/// auf dem Rechner mit.
public enum RevocationListVerifier {

    public enum Failure: Error, Equatable {
        /// Kein hinterlegtes Zertifikat traegt den Ausstellernamen der Liste.
        case noMatchingAuthority
        /// Das Verfahren ist bekannt, aber hier nicht umgesetzt.
        case unsupportedAlgorithm(String)
        /// Die Signatur passt nicht.
        case badSignature
        /// Aus dem Zertifikat liess sich kein Schluessel gewinnen.
        case unreadableAuthority
    }

    /// Prueft die Liste gegen die uebergebenen Zertifikate (DER).
    ///
    /// Gibt `nil`, wenn die Liste besteht, sonst den Grund. Kein `Result<Void,_>`:
    /// das liesse sich nicht vergleichen, und ein Test, der das Ergebnis nicht
    /// vergleichen kann, prueft nichts.
    ///
    /// Vorrang haben die Zertifikate, deren Subjektname dem Aussteller der Liste
    /// entspricht. Passt keiner, wird nicht auf gut Glueck weitergeprueft: eine
    /// Liste, deren Aussteller nicht im Vertrauensspeicher steht, ist keine, der
    /// zu glauben waere.
    public static func verify(
        _ list: RevocationList,
        against certificates: [Data]
    ) -> Failure? {
        let matching = certificates.filter { certificate in
            guard let subject = try? CertificateReader.subject(
                ofCertificate: [UInt8](certificate)
            ) else { return false }
            return subject == list.issuerDER
        }
        guard !matching.isEmpty else { return .noMatchingAuthority }

        let algorithm: SecKeyAlgorithm
        switch secKeyAlgorithm(for: list) {
        case .success(let value): algorithm = value
        case .failure(let error): return error
        }

        var sawKey = false
        for certificate in matching {
            guard
                let secCertificate = SecCertificateCreateWithData(nil, certificate as CFData),
                let key = SecCertificateCopyKey(secCertificate)
            else { continue }
            sawKey = true
            guard SecKeyIsAlgorithmSupported(key, .verify, algorithm) else { continue }
            if SecKeyVerifySignature(
                key,
                algorithm,
                Data(list.signedBytes) as CFData,
                Data(list.signature) as CFData,
                nil
            ) {
                return nil
            }
        }
        return sawKey ? .badSignature : .unreadableAuthority
    }

    // MARK: - Verfahren

    private static let rsaPKCS1SHA1 = "1.2.840.113549.1.1.5"
    private static let rsaPKCS1SHA256 = "1.2.840.113549.1.1.11"
    private static let rsaPKCS1SHA384 = "1.2.840.113549.1.1.12"
    private static let rsaPKCS1SHA512 = "1.2.840.113549.1.1.13"
    private static let rsaPSS = "1.2.840.113549.1.1.10"
    private static let ecdsaSHA256 = "1.2.840.10045.4.3.2"
    private static let ecdsaSHA384 = "1.2.840.10045.4.3.3"
    private static let ecdsaSHA512 = "1.2.840.10045.4.3.4"

    static func secKeyAlgorithm(
        for list: RevocationList
    ) -> Result<SecKeyAlgorithm, Failure> {
        switch list.signatureAlgorithm {
        case rsaPKCS1SHA1: return .success(.rsaSignatureMessagePKCS1v15SHA1)
        case rsaPKCS1SHA256: return .success(.rsaSignatureMessagePKCS1v15SHA256)
        case rsaPKCS1SHA384: return .success(.rsaSignatureMessagePKCS1v15SHA384)
        case rsaPKCS1SHA512: return .success(.rsaSignatureMessagePKCS1v15SHA512)
        case ecdsaSHA256: return .success(.ecdsaSignatureMessageX962SHA256)
        case ecdsaSHA384: return .success(.ecdsaSignatureMessageX962SHA384)
        case ecdsaSHA512: return .success(.ecdsaSignatureMessageX962SHA512)
        case rsaPSS:
            guard let parameters = list.signatureParameters else {
                // Ohne Parameter waere SHA-1 die Vorgabe der Norm. Das ist heute
                // niemandes Absicht, und zu raten ist hier das Falsche.
                return .failure(.unsupportedAlgorithm("RSASSA-PSS ohne Parameter"))
            }
            return pssAlgorithm(parameters: parameters)
        default:
            return .failure(.unsupportedAlgorithm(list.signatureAlgorithm))
        }
    }

    /// Die Hashfunktion aus den PSS-Parametern.
    ///
    /// ```
    /// RSASSA-PSS-params ::= SEQUENCE {
    ///     hashAlgorithm    [0] AlgorithmIdentifier DEFAULT sha1,
    ///     maskGenAlgorithm [1] AlgorithmIdentifier DEFAULT mgf1SHA1,
    ///     saltLength       [2] INTEGER DEFAULT 20,
    ///     trailerField     [3] INTEGER DEFAULT 1 }
    /// ```
    ///
    /// `Security` kennt PSS nur mit **Salzlaenge gleich Hashlaenge**. Steht dort
    /// etwas anderes, wird das gesagt und nicht stillschweigend als „Signatur
    /// falsch" ausgegeben - der Unterschied zwischen „koennen wir nicht pruefen"
    /// und „ist gefaelscht" ist der ganze Punkt.
    static func pssAlgorithm(parameters: [UInt8]) -> Result<SecKeyAlgorithm, Failure> {
        var digestOID = "1.3.14.3.2.26"  // SHA-1, die Vorgabe der Norm
        var saltLength = 20

        var outer = DER.Cursor(parameters)
        if let fields = try? outer.next(expecting: DER.sequence) {
            var cursor = DER.into(fields)
            while let element = try? cursor.next() {
                switch element.contextTagNumber {
                case 0:
                    var inner = DER.Cursor(element.content)
                    if let identifier = try? inner.next(expecting: DER.sequence) {
                        var identifierFields = DER.into(identifier)
                        if let oid = try? identifierFields.next(expecting: DER.objectIdentifier),
                           let text = try? DER.oid(oid) {
                            digestOID = text
                        }
                    }
                case 2:
                    var inner = DER.Cursor(element.content)
                    if let integer = try? inner.next(expecting: DER.integer),
                       let hex = try? DER.integerHex(integer),
                       let value = Int(hex, radix: 16) {
                        saltLength = value
                    }
                default:
                    break
                }
            }
        }

        let expected: (algorithm: SecKeyAlgorithm, digestBytes: Int)
        switch digestOID {
        case "2.16.840.1.101.3.4.2.1": expected = (.rsaSignatureMessagePSSSHA256, 32)
        case "2.16.840.1.101.3.4.2.2": expected = (.rsaSignatureMessagePSSSHA384, 48)
        case "2.16.840.1.101.3.4.2.3": expected = (.rsaSignatureMessagePSSSHA512, 64)
        case "1.3.14.3.2.26": expected = (.rsaSignatureMessagePSSSHA1, 20)
        default:
            return .failure(.unsupportedAlgorithm("PSS mit \(digestOID)"))
        }
        guard saltLength == expected.digestBytes else {
            return .failure(
                .unsupportedAlgorithm("PSS mit Salzlaenge \(saltLength)")
            )
        }
        return .success(expected.algorithm)
    }
}
