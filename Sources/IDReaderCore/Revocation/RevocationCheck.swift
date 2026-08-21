import Foundation

/// Auf welchen Signierer sich eine Sperrpruefung bezieht.
///
/// Zwei Angaben, beide aus dem Dokumentsignierer-Zertifikat: seine Seriennummer
/// und der Abdruck des Namens seines Ausstellers. Mehr braucht der Vergleich mit
/// einer Sperrliste nicht, und mehr wird deshalb nicht aufbewahrt.
public struct SignerReference: Sendable, Equatable, Hashable, Codable {

    /// Die Seriennummer des Signierers, Grossbuchstaben-Hex ohne fuehrende Nullen.
    public let serialHex: String

    /// SHA-256 ueber die Bytes des Ausstellernamens.
    public let issuerDigest: String

    public init(serialHex: String, issuerDigest: String) {
        self.serialHex = serialHex
        self.issuerDigest = issuerDigest
    }

    public init(_ identity: CertificateIdentity) {
        self.serialHex = identity.serialHex
        self.issuerDigest = identity.issuerDigest
    }
}

/// Das Ergebnis eines Abgleichs mit einer Sperrliste.
public enum RevocationOutcome: String, Sendable, Codable, CaseIterable {
    /// Die Liste kennt diese Nummer nicht - der Signierer gilt.
    case notRevoked
    /// Die Nummer steht auf der Liste.
    case revoked
    /// Es liegt eine Liste vor, aber nicht von diesem Aussteller.
    ///
    /// Kein Fehler und kein Verdacht. Von den neun hinterlegten italienischen
    /// CSCA-Zertifikaten nennen sechs eine Verteilstelle, drei nicht; wer von
    /// einem der drei signiert wurde, ist nicht zu pruefen. Das gehoert gesagt
    /// und nicht als „nicht gesperrt" ausgegeben.
    case noListForIssuer
}

/// Wann gegen welche Liste geprueft wurde, und mit welchem Ergebnis.
///
/// ## Warum drei Zeitangaben und nicht eine
///
/// „Geprueft" allein ist keine Aussage. Eine Pruefung von heute gegen eine Liste
/// von vor zwei Jahren sagt kaum etwas, eine von vor zwei Wochen gegen die Liste
/// von damals sagt viel. Der Datensatz traegt daher beides: **wann** geprueft
/// wurde und **welche** Liste dabei vorlag. Ob das genuegt, entscheidet der, der
/// hinsieht - die App entscheidet es nicht fuer ihn.
public struct RevocationCheck: Sendable, Equatable, Codable {

    public let outcome: RevocationOutcome

    /// Wann die App den Abgleich gerechnet hat.
    public let checkedAt: Date

    /// Das Ausgabedatum der Liste, gegen die abgeglichen wurde.
    public let listIssuedAt: Date

    /// Wann die Liste sich selbst fuer ueberholt erklaert, wenn sie es sagt.
    public let listExpiresAt: Date?

    public init(
        outcome: RevocationOutcome,
        checkedAt: Date,
        listIssuedAt: Date,
        listExpiresAt: Date?
    ) {
        self.outcome = outcome
        self.checkedAt = Self.whole(checkedAt)
        self.listIssuedAt = Self.whole(listIssuedAt)
        self.listExpiresAt = listExpiresAt.map(Self.whole)
    }

    /// Auf ganze Millisekunden gerundet - die Einheit des Archivformats.
    ///
    /// `Date()` traegt Mikrosekunden, die Datei nicht. Ohne diese Rundung ist ein
    /// frisch gebildeter Abgleich nie gleich dem geladenen, und genau dieser
    /// Vergleich entscheidet, ob ueberhaupt geschrieben werden muss - der Nachhol-
    /// durchgang wuerde die Archivdatei bei jedem Aufruf neu schreiben.
    private static func whole(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    /// Ob die verwendete Liste zum Zeitpunkt `now` bereits ueberholt war.
    public func usedStaleList(at now: Date) -> Bool {
        guard let listExpiresAt else { return false }
        return now >= listExpiresAt
    }

    /// Ob es sich lohnt, diese Pruefung mit einer neueren Liste zu wiederholen.
    ///
    /// Zwei Faelle: die Liste war nicht die des Ausstellers, oder die neue Liste
    /// ist juenger als die damals verwendete. Ein bereits gesperrter Signierer
    /// wird nicht erneut geprueft - eine Sperre wird nicht zurueckgenommen.
    public func deservesRetry(withListIssuedAt newer: Date) -> Bool {
        guard outcome != .revoked else { return false }
        if outcome == .noListForIssuer { return true }
        return newer > listIssuedAt
    }
}
