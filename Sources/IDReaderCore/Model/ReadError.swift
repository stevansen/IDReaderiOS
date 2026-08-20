import Foundation

/// Fehlerarten, die die Oberflaeche unterscheiden muss.
///
/// Bewusst ohne Text: die Meldungen liegen im Lokalisierungskatalog, damit die
/// Leseschicht frei von Oberflaechenbezuegen bleibt.
public enum ReadErrorKind: Sendable, CaseIterable {
    /// PACE fehlgeschlagen - mit sehr hoher Wahrscheinlichkeit falsche CAN.
    case wrongCan

    /// PACE oder BAC mit dem MRZ-Schluessel fehlgeschlagen.
    ///
    /// Eigene Art und nicht ``wrongCan``, weil die Meldung etwas anderes sagen
    /// muss: drei Felder koennen falsch sein, nicht eines, und die Pruefziffern
    /// sind eine haeufige Fehlerquelle beim Abtippen.
    case wrongMrzKey

    /// Karte wurde waehrend des Lesens entfernt oder die Verbindung brach ab.
    case connectionLost

    /// Geraet unterstuetzt keine Extended-Length-APDUs und scheitert daran.
    case extendedLengthUnsupported

    /// Der erkannte Tag ist keine ISO-14443-4-Karte.
    case unsupportedTag

    /// Karte antwortet, liefert aber keine PACE-Parameter (kein CIE 3.0 / ePass).
    case noPaceSupport

    /// In dieser Fassung ist kein PACE-Backend eingebunden.
    ///
    /// Eine eigene Art und keine Faltung in ``unknown``: „unbekannter Fehler"
    /// schickt den Bediener los, die Karte zu putzen und das Handy neu zu
    /// starten. Was hier fehlt, ist aber nichts an der Karte, sondern etwas am
    /// Programm - und das gehoert gesagt. Siehe docs/NFC-PACE.md.
    case paceUnavailable

    /// Alles andere.
    case unknown

    public var messageKey: StringKey {
        switch self {
        case .wrongCan: .errorWrongCan
        case .wrongMrzKey: .errorWrongMrzKey
        case .connectionLost: .errorConnectionLost
        case .extendedLengthUnsupported: .errorExtendedLength
        case .unsupportedTag: .errorUnsupportedTag
        case .noPaceSupport: .errorNoPace
        case .paceUnavailable: .errorPaceUnavailable
        case .unknown: .errorUnknown
        }
    }
}

/// Fehler beim Lesen. ``kind`` steuert die Meldung, ``detail`` ist nur fuer
/// Entwicklerprotokolle gedacht und enthaelt keine Personendaten.
public struct ReadError: Error, Sendable {
    public let kind: ReadErrorKind
    public let detail: String

    public init(_ kind: ReadErrorKind, _ detail: String = "") {
        self.kind = kind
        self.detail = detail
    }
}

/// Was die Texterkennung gerade tut, und woran sie gescheitert ist.
///
/// Ein gemeinsamer Zustand fuer alle drei Dokumentarten. Nicht jede Art kann
/// jeden Grund erreichen - die MRZ eines Passes ist durch ihre Pruefziffern nie
/// mehrdeutig, also gibt es dort kein ``ambiguous``. Die Masken uebersetzen nur
/// die Gruende, die bei ihnen vorkommen, und fassen den Rest als allgemeinen
/// Fehlschlag.
public enum ScanState: Sendable, Equatable {
    case idle
    /// Ein Foto wird ausgewertet.
    case working
    /// Nichts Passendes im Bild gefunden.
    case notFound
    /// Es war die falsche Seite: gesucht war die CAN von der Vorderseite, im Bild
    /// steht eine maschinenlesbare Zone.
    case wrongSide
    /// Mehrere gleich plausible Kandidaten. Betrifft nur die CAN.
    case ambiguous
    /// Die Aufnahme oder die Erkennung selbst ist gescheitert.
    case failed
}
