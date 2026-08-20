import Foundation
import IDReaderCore

/// Was die App vom Chip braucht.
///
/// Ein Protokoll und keine Klasse, weil hinter dieser Grenze der Teil liegt, der
/// noch nicht fertig ist: PACE ueber brainpoolP256r1. Die Grenze steht genau
/// dort, wo die Portierung aufhoert und die Kryptografie anfaengt - alles
/// darueber (Oberflaeche, Archiv, Export, Pruefurteil) ist fertig und laesst sich
/// gegen eine Attrappe pruefen, ohne auf ein Backend zu warten.
///
/// Siehe docs/NFC-PACE.md.
///
/// `@MainActor`: CoreNFC gibt seine Objekte - Sitzung und Tag - nicht als
/// `Sendable` heraus, und sie gehoeren dem Ablauf, der sie entdeckt hat. Den
/// ganzen Leseweg auf einen Faden zu legen ist deshalb keine Einschraenkung,
/// sondern die Beschreibung dessen, was ohnehin gilt - und die Kartenkommunikation
/// selbst wartet, sie rechnet nicht.
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

/// Die gesicherte Verbindung - der Teil, der Kryptografie braucht, die das
/// System nicht mitbringt.
///
/// ## Warum das hier eine Grenze ist und keine Faulheit
///
/// PACE nach ICAO 9303 Teil 11 rechnet bei der italienischen CIE ueber
/// **brainpoolP256r1**. CryptoKit fuehrt P-256, P-384, P-521 und Curve25519 -
/// brainpool nicht. Es gibt damit drei Wege, und nur drei:
///
/// 1. `NFCPassportReader` (MIT) einbinden, das OpenSSL mitbringt, und den
///    fehlenden CAN-Fall nachtragen. Der Patch ist sechs Zeilen und steht in
///    docs/NFC-PACE.md. **Das ist der empfohlene Weg.**
/// 2. OpenSSL selbst einbinden und den Ablauf schreiben.
/// 3. Eigene EC-Arithmetik. Das kommt nicht in Frage: handgeschriebene
///    Kryptografie in einer App, die Ausweise liest, ist kein Sparen, sondern
///    ein Risiko, das niemand mehr sieht.
///
/// Bewusst **ohne** `Sendable` an der Uebertragungsfunktion: sie schliesst den
/// `NFCISO7816Tag` ein, und der ist nicht `Sendable`. Ein Tag gehoert der
/// Sitzung, die ihn entdeckt hat, und wird ohnehin nur aus deren Ablauf heraus
/// angesprochen - die Kennzeichnung wuerde eine Zusage machen, die CoreNFC nicht
/// gibt, und dafuer eine Absicherung erzwingen, die es nicht braucht.
@MainActor
protocol PACEEngine {
    /// Fuehrt PACE durch und gibt einen Kanal zurueck, ueber den die
    /// Datengruppen gelesen werden.
    func establish(
        info: PaceInfo,
        key: AccessKey,
        transceive: @escaping ([UInt8]) async throws -> [UInt8]
    ) async throws -> SecureChannel
}

/// Der gesicherte Kanal: dieselben APDUs, nur verpackt.
protocol SecureChannel {
    func send(_ apdu: [UInt8]) async throws -> [UInt8]
}

/// Das Backend, solange keines eingebunden ist.
///
/// Wirft einen **benannten** Fehler und nicht `unknown`. Der Unterschied ist der
/// ganze Punkt: „unbekannter Fehler beim Lesen der Karte" schickt den Bediener
/// los, die Karte zu putzen und das Telefon neu zu starten. Was hier fehlt, ist
/// aber nichts an der Karte.
struct UnavailablePACEEngine: PACEEngine {
    func establish(
        info: PaceInfo,
        key: AccessKey,
        transceive: @escaping ([UInt8]) async throws -> [UInt8]
    ) async throws -> SecureChannel {
        throw ReadError(
            .paceUnavailable,
            "kein PACE-Backend eingebunden (OID \(info.objectIdentifier), "
                + "Parameter \(info.parameterId.map(String.init) ?? "-"))"
        )
    }
}
