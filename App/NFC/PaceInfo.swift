import Foundation
import IDReaderCore

/// Die PACE-Angaben aus `EF.CardAccess`.
///
/// Sie sagen, mit welchem Verfahren und ueber welcher Kurve der Chip die
/// gesicherte Verbindung erwartet. Ohne sie kann eine CIE 3.0 nicht gelesen
/// werden - und eine Karte, die keine liefert, ist keine CIE 3.0. Genau so
/// meldet es die App auch.
struct PaceInfo: Sendable, Equatable {
    /// Die Protokoll-Objektkennung, z. B. `0.4.0.127.0.7.2.2.4.2.4`
    /// (id-PACE-ECDH-GM-AES-CBC-CMAC-256).
    let objectIdentifier: String
    /// Fassung des Verfahrens; nach TR-03110 ist das 2.
    let version: Int
    /// Kennung der Domainparameter - bei der CIE 13, also brainpoolP256r1.
    ///
    /// Optional, weil TR-03110 sie nur verlangt, wenn die Kennung nicht schon in
    /// der Objektkennung steckt.
    let parameterId: Int?

    /// Der Praefix, unter dem TR-03110 alle PACE-Verfahren fuehrt.
    static let paceOidPrefix = "0.4.0.127.0.7.2.2.4"

    /// Zieht den ersten PACEInfo aus dem Inhalt von `EF.CardAccess`.
    ///
    /// Die Datei ist ein `SET OF SecurityInfo`; jeder Eintrag eine `SEQUENCE`,
    /// die mit ihrer Objektkennung beginnt. Genommen wird der erste Eintrag mit
    /// einer PACE-Kennung - dieselbe Wahl wie in der Android-Fassung, wo JMRTD
    /// `filterIsInstance<PACEInfo>().firstOrNull()` liefert.
    static func first(inCardAccess bytes: [UInt8]) throws -> PaceInfo? {
        let root = try DER.read(bytes)
        for entry in try DER.children(of: root) {
            guard entry.isConstructed else { continue }
            let fields = try DER.children(of: entry)
            guard let oid = fields.first.flatMap(DER.objectIdentifier),
                  oid.hasPrefix(paceOidPrefix)
            else { continue }

            let numbers = fields.dropFirst().compactMap(DER.integer)
            return PaceInfo(
                objectIdentifier: oid,
                version: numbers.first ?? 2,
                parameterId: numbers.count > 1 ? numbers[1] : nil
            )
        }
        return nil
    }
}
