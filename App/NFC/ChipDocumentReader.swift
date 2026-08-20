import Foundation
import IDReaderCore

/// Was die App vom Chip braucht.
///
/// `@MainActor`: CoreNFC gibt seine Objekte - Sitzung und Tag - nicht als
/// `Sendable` heraus, und sie gehoeren dem Ablauf, der sie entdeckt hat. Den
/// Leseweg auf einen Faden zu legen ist deshalb keine Einschraenkung, sondern
/// die Beschreibung dessen, was ohnehin gilt: die Kartenkommunikation wartet, sie
/// rechnet nicht.
///
/// Ein Protokoll und keine Klasse, damit die Oberflaeche gegen eine Attrappe zu
/// pruefen ist, ohne eine Karte in der Hand zu haben - siehe ``StubChipReader``.
@MainActor
protocol ChipDocumentReader {
    /// Ob dieses Geraet ueberhaupt NFC lesen kann.
    var isAvailable: Bool { get }

    /// Liest ein Dokument.
    ///
    /// - Parameters:
    ///   - key: CAN bei der CIE, MRZ-Schluessel beim Pass.
    ///   - readPhoto: DG2 mitlesen. Das Lichtbild ist mit Abstand die groesste
    ///     Datengruppe und verlaengert den Vorgang deutlich - deshalb ist es
    ///     abwaehlbar. Die Echtheitspruefung bleibt vollwertig, sie deckt dann
    ///     eben DG1 und DG11 ab statt drei Datengruppen.
    ///   - onProgress: wird bei jedem Schritt aufgerufen.
    func read(
        key: AccessKey,
        readPhoto: Bool,
        onProgress: @escaping (ReadStep) -> Void
    ) async throws -> DocumentData

    /// Bricht eine laufende Uebertragung ab.
    func abort()
}
