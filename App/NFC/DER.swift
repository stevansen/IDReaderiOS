import Foundation

/// Ein sehr kleiner DER-Leser.
///
/// Gebraucht wird davon genau eine Sache: aus `EF.CardAccess` den `PACEInfo`
/// herausholen, also eine Objektkennung und eine ganze Zahl. Ein vollstaendiger
/// ASN.1-Werkzeugkasten waere dafuer eine Abhaengigkeit, die dann alles andere
/// mitbringt - und die Datei, um die es geht, ist zwei Dutzend Bytes gross.
///
/// Was hier **nicht** hineingehoert: das Zerlegen der Datengruppen oder des
/// Sicherheitsobjekts. Das braucht eine geprueft vollstaendige Umsetzung, und die
/// kommt mit dem PACE-Backend (siehe docs/NFC-PACE.md).
enum DER {

    struct Element {
        let tag: UInt8
        /// Nur der Inhalt, ohne Kennung und Laenge.
        let value: [UInt8]
        /// Wie viele Bytes das Element insgesamt belegt hat.
        let totalLength: Int

        var isConstructed: Bool { tag & 0x20 != 0 }
    }

    enum Failure: Error {
        case truncated
        case unsupportedLength
    }

    /// Liest das Element, das an `offset` beginnt.
    static func read(_ bytes: [UInt8], at offset: Int = 0) throws -> Element {
        guard offset < bytes.count else { throw Failure.truncated }
        var cursor = offset
        let tag = bytes[cursor]
        cursor += 1

        // Mehrbyte-Kennungen kommen in EF.CardAccess nicht vor; kaeme eine, waere
        // ein stilles Weiterlesen der falsche Umgang damit.
        guard tag & 0x1F != 0x1F else { throw Failure.unsupportedLength }
        guard cursor < bytes.count else { throw Failure.truncated }

        var length = Int(bytes[cursor])
        cursor += 1
        if length & 0x80 != 0 {
            let count = length & 0x7F
            guard count > 0, count <= 4, cursor + count <= bytes.count else {
                throw Failure.unsupportedLength
            }
            length = 0
            for _ in 0..<count {
                length = (length << 8) | Int(bytes[cursor])
                cursor += 1
            }
        }

        guard cursor + length <= bytes.count else { throw Failure.truncated }
        return Element(
            tag: tag,
            value: Array(bytes[cursor..<(cursor + length)]),
            totalLength: (cursor - offset) + length
        )
    }

    /// Alle Elemente hintereinander, so wie sie in einem SET oder einer SEQUENCE
    /// stehen.
    static func children(of element: Element) throws -> [Element] {
        var out: [Element] = []
        var offset = 0
        while offset < element.value.count {
            let child = try read(element.value, at: offset)
            out.append(child)
            offset += child.totalLength
        }
        return out
    }

    /// Eine Objektkennung in Punktschreibweise.
    static func objectIdentifier(_ element: Element) -> String? {
        guard element.tag == 0x06, let first = element.value.first else { return nil }

        var parts = ["\(first / 40)", "\(first % 40)"]
        var value = 0
        for byte in element.value.dropFirst() {
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                parts.append("\(value)")
                value = 0
            }
        }
        return parts.joined(separator: ".")
    }

    /// Eine ganze Zahl, sofern sie in ein `Int` passt.
    static func integer(_ element: Element) -> Int? {
        guard element.tag == 0x02, !element.value.isEmpty, element.value.count <= 8 else {
            return nil
        }
        var result = 0
        for byte in element.value {
            result = (result << 8) | Int(byte)
        }
        return result
    }
}
