import Foundation

/// Eine gelesene Sperrliste (X.509 CRL).
///
/// ## Was eine Sperrliste sagt, und was nicht
///
/// Sie sagt: **dieses Signierzertifikat gilt nicht mehr**. Steht die Nummer des
/// Dokumentsignierers darauf, dann taugt seine Signatur nicht mehr als Beweis,
/// und jedes Dokument, das er signiert hat, ist damit ungeprueft.
///
/// Sie sagt **nicht**, dass ein bestimmtes Dokument verloren, gestohlen oder
/// eingezogen wurde. Das steht in Fahndungsbestaenden - fuer Reisedokumente in
/// der SLTD von Interpol -, und die sind keiner oeffentlichen App zugaenglich.
/// Wer von dieser Pruefung „ist dieser Ausweis gesperrt?" erwartet, erwartet das
/// Falsche, und die Oberflaeche sagt deshalb „Signierer" und nicht „Dokument".
///
/// ## Aufbau
///
/// ```
/// CertificateList ::= SEQUENCE {
///     tbsCertList         TBSCertList,
///     signatureAlgorithm  AlgorithmIdentifier,
///     signatureValue      BIT STRING }
///
/// TBSCertList ::= SEQUENCE {
///     version              INTEGER OPTIONAL,
///     signature            AlgorithmIdentifier,
///     issuer               Name,
///     thisUpdate           Time,
///     nextUpdate           Time OPTIONAL,
///     revokedCertificates  SEQUENCE OF SEQUENCE {
///         userCertificate      INTEGER,
///         revocationDate       Time,
///         crlEntryExtensions   Extensions OPTIONAL } OPTIONAL,
///     crlExtensions    [0] EXPLICIT Extensions OPTIONAL }
/// ```
public struct RevocationList: Sendable {

    /// Die Bytes des Ausstellernamens.
    public let issuerDER: [UInt8]

    /// Wann die Liste ausgegeben wurde.
    public let thisUpdate: Date

    /// Wann die naechste Liste erwartet wird, wenn die Liste es sagt.
    public let nextUpdate: Date?

    /// Die gesperrten Nummern, als Grossbuchstaben-Hex ohne fuehrende Nullen.
    public let revokedSerials: Set<String>

    /// Die vollstaendige Kodierung von `tbsCertList` - das, was signiert wurde.
    public let signedBytes: [UInt8]

    /// Der OID des Signaturverfahrens.
    public let signatureAlgorithm: String

    /// Die Parameter des Signaturverfahrens, sofern welche dabeistehen.
    ///
    /// Braucht RSASSA-PSS: dort steht die Hashfunktion nicht im OID, sondern in
    /// den Parametern. Die italienischen CSCA ab 2020 signieren mit PSS.
    public let signatureParameters: [UInt8]?

    /// Die Signatur.
    public let signature: [UInt8]

    public var issuerDigest: String { CertificateIdentity.digest(of: issuerDER) }

    /// Ob die Liste zum Zeitpunkt `now` noch die aktuelle sein sollte.
    ///
    /// Eine abgelaufene Liste wird **nicht** verworfen. Sie ist das Beste, was da
    /// ist, und eine Pruefung gegen eine alte Liste ist mehr als keine - solange
    /// dem Benutzer gesagt wird, wie alt sie war. Genau dafuer steht
    /// ``RevocationCheck/listIssuedAt`` im Datensatz.
    public func isCurrent(at now: Date) -> Bool {
        guard let nextUpdate else { return true }
        return now < nextUpdate
    }

    public func revokes(_ serialHex: String) -> Bool {
        revokedSerials.contains(serialHex.uppercased())
    }

    /// Liest eine Sperrliste aus DER.
    public static func parse(_ der: [UInt8]) throws -> RevocationList {
        var outer = DER.Cursor(der)
        let list = try outer.next(expecting: DER.sequence)
        var body = DER.into(list)

        let tbs = try body.next(expecting: DER.sequence)
        let algorithm = try body.next(expecting: DER.sequence)
        let signatureBits = try body.next(expecting: DER.bitString)

        var algorithmFields = DER.into(algorithm)
        let algorithmOID = try DER.oid(try algorithmFields.next(expecting: DER.objectIdentifier))
        let parameters = try algorithmFields.peek().flatMap { element -> [UInt8]? in
            element.tag == DER.null ? nil : element.encoded
        }

        // Eine BIT STRING traegt vorn die Zahl der unbenutzten Bits. Bei einer
        // Signatur ist die immer 0, aber sie steht da und gehoert nicht zum Wert.
        guard let unusedBits = signatureBits.content.first, unusedBits == 0 else {
            throw DER.Failure.malformedInteger
        }
        let signature = Array(signatureBits.content.dropFirst())

        var fields = DER.into(tbs)
        var element = try fields.next()
        // Die Fassung ist freigestellt. Eine CRL mit gesperrten Eintraegen ist in
        // der Praxis immer v2, aber verlassen kann man sich darauf nicht.
        if element.tag == DER.integer {
            element = try fields.next()
        }
        guard element.tag == DER.sequence else {
            throw DER.Failure.unexpectedTag(element.tag)  // signature AlgorithmIdentifier
        }
        let issuer = try fields.next(expecting: DER.sequence)
        let thisUpdate = try DER.time(try fields.next())

        var nextUpdate: Date?
        var revoked = Set<String>()

        while let upcoming = try fields.peek() {
            if upcoming.tag == DER.utcTime || upcoming.tag == DER.generalizedTime {
                nextUpdate = try DER.time(try fields.next())
                continue
            }
            if upcoming.tag == DER.sequence {
                let entries = try fields.next(expecting: DER.sequence)
                var entryCursor = DER.into(entries)
                while !entryCursor.isAtEnd {
                    let entry = try entryCursor.next(expecting: DER.sequence)
                    var entryFields = DER.into(entry)
                    let serial = try DER.integerHex(try entryFields.next(expecting: DER.integer))
                    revoked.insert(serial)
                }
                continue
            }
            // crlExtensions und alles Weitere wird nicht gebraucht.
            _ = try fields.next()
        }

        return RevocationList(
            issuerDER: issuer.encoded,
            thisUpdate: thisUpdate,
            nextUpdate: nextUpdate,
            revokedSerials: revoked,
            signedBytes: tbs.encoded,
            signatureAlgorithm: algorithmOID,
            signatureParameters: parameters,
            signature: signature
        )
    }
}
