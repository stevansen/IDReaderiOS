import Foundation
import IDReaderCore

/// Was ein Lesevorgang hergibt.
///
/// Zwei Dinge, und das zweite gehoert ausdruecklich **nicht** in
/// ``DocumentData``: der Dokumentsignierer ist keine Angabe ueber die Person,
/// sondern ueber die Stelle, die das Dokument signiert hat. Er steht in keiner
/// Ausgabe und in keinem Bericht - er ist nur da, damit die Sperrpruefung spaeter
/// nachzuholen ist.
struct ChipReadResult {
    let data: DocumentData
    let signer: SignerReference?
}

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
/// Was das Systemblatt gerade sagen soll.
///
/// Zwei Faelle, und der zweite ist der Grund fuer diesen Typ: `step(for:)`
/// bildet die Fehlermeldung der Bibliothek auf ``ReadStep/verifying`` ab, weil
/// es dafuer keinen eigenen Schritt gibt. Auf dem Fortschrittsbalken ist das
/// harmlos - auf dem Systemblatt stuende dann „Echtheit pruefen", waehrend
/// gerade nichts mehr geprueft wird.
enum NFCSheetStage {
    case step(ReadStep)
    case failed
}

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
    ///   - sheetMessage: der Text im **Systemblatt**, das iOS ueber die App legt,
    ///     solange die Sitzung laeuft. Er kommt von aussen herein, weil nur der
    ///     Aufrufer die Sprache und die gewaehlte Dokumentart kennt - und weil er
    ///     sonst aus der Lesebibliothek kommt und dann auf Englisch von einem
    ///     „passport" spricht, auch wenn eine Karte aufliegt.
    func read(
        key: AccessKey,
        readPhoto: Bool,
        sheetMessage: @escaping (NFCSheetStage) -> String,
        onProgress: @escaping (ReadStep) -> Void
    ) async throws -> ChipReadResult

    /// Bricht eine laufende Uebertragung ab.
    func abort()
}
