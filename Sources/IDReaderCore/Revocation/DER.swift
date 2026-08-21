import Foundation

/// Ein Leser fuer DER, so klein wie es fuer Zertifikate und Sperrlisten reicht.
///
/// ## Warum eigenhaendig
///
/// Zu parsen sind zwei Strukturen: das Dokumentsignierer-Zertifikat, aus dem
/// Seriennummer und Ausstellername gebraucht werden, und die Sperrliste selbst.
/// Beides koennte OpenSSL, das in `ThirdParty/` ohnehin mitgebaut wird - aber
/// dann lebte der Code dort, wo `swift test` auf dem Rechner nicht hinkommt, und
/// eine Sperrpruefung ohne Tests ist keine.
///
/// Deshalb hier, in reinem Swift, mit dem einen Satz Regeln, den DER kennt:
/// jedes Element ist Tag, Laenge, Inhalt, und die Laenge ist immer angegeben.
/// Unbestimmte Laengen (BER) gibt es in DER nicht und werden abgewiesen.
///
/// ## Was der Leser nicht tut
///
/// Er versteht keine Zeichensatzkodierungen und keine Namensbestandteile. Ein
/// Ausstellername wird nie in Text verwandelt, sondern als **Bytes** verglichen -
/// genau so, wie RFC 5280 es fuer die Zuordnung Sperrliste-zu-Aussteller
/// vorsieht. Das erspart die ganze Kodierungsfrage und ist zugleich das
/// strengere Verfahren.
enum DER {

    /// Ein einzelnes Element.
    struct Element {
        /// Das Identifikationsbyte, z. B. `0x30` fuer SEQUENCE.
        let tag: UInt8
        /// Der Inhalt ohne Tag und Laenge.
        let content: [UInt8]
        /// Tag, Laenge und Inhalt zusammen.
        ///
        /// Gebraucht fuer die Signaturpruefung: signiert wurde die vollstaendige
        /// Kodierung von `tbsCertList`, nicht ihr Inhalt.
        let encoded: [UInt8]

        var isConstructed: Bool { tag & 0x20 != 0 }

        /// Die Nummer eines kontextspezifischen Tags, z. B. 0 fuer `[0]`.
        var contextTagNumber: UInt8? {
            (tag & 0xC0) == 0x80 ? tag & 0x1F : nil
        }
    }

    enum Failure: Error, Equatable {
        case truncated
        case indefiniteLength
        case lengthTooLarge
        case unexpectedTag(UInt8)
        case notFound(String)
        case malformedInteger
        case malformedTime(String)
    }

    /// Laeuft ueber eine Folge von Elementen.
    struct Cursor {
        private let bytes: [UInt8]
        private var index: Int

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
            self.index = 0
        }

        var isAtEnd: Bool { index >= bytes.count }

        /// Liest das naechste Element und rueckt vor.
        mutating func next() throws -> Element {
            let start = index
            guard index < bytes.count else { throw Failure.truncated }
            let tag = bytes[index]
            index += 1
            guard index < bytes.count else { throw Failure.truncated }

            var length = 0
            let first = bytes[index]
            index += 1
            if first & 0x80 == 0 {
                length = Int(first)
            } else {
                let count = Int(first & 0x7F)
                // 0x80 waere unbestimmte Laenge: in BER erlaubt, in DER nicht.
                guard count > 0 else { throw Failure.indefiniteLength }
                // Mehr als vier Laengenbytes hiesse ein Element ueber 4 GB. Eine
                // Sperrliste dieser Groesse ist kein Eingabefall, sondern ein
                // Angriff.
                guard count <= 4 else { throw Failure.lengthTooLarge }
                guard index + count <= bytes.count else { throw Failure.truncated }
                for _ in 0 ..< count {
                    length = (length << 8) | Int(bytes[index])
                    index += 1
                }
            }

            guard length >= 0, index + length <= bytes.count else {
                throw Failure.truncated
            }
            let content = Array(bytes[index ..< index + length])
            index += length
            return Element(tag: tag, content: content, encoded: Array(bytes[start ..< index]))
        }

        /// Liest das naechste Element und verlangt einen bestimmten Tag.
        mutating func next(expecting tag: UInt8) throws -> Element {
            let element = try next()
            guard element.tag == tag else { throw Failure.unexpectedTag(element.tag) }
            return element
        }

        /// Schaut das naechste Element an, ohne vorzuruecken.
        func peek() throws -> Element? {
            guard !isAtEnd else { return nil }
            var copy = self
            return try copy.next()
        }
    }

    static let sequence: UInt8 = 0x30
    static let set: UInt8 = 0x31
    static let integer: UInt8 = 0x02
    static let bitString: UInt8 = 0x03
    static let octetString: UInt8 = 0x04
    static let objectIdentifier: UInt8 = 0x06
    static let null: UInt8 = 0x05
    static let utcTime: UInt8 = 0x17
    static let generalizedTime: UInt8 = 0x18

    /// Oeffnet ein SEQUENCE und gibt einen Cursor auf seinen Inhalt.
    static func into(_ element: Element) -> Cursor { Cursor(element.content) }

    /// Ein INTEGER als Grossbuchstaben-Hex ohne fuehrende Nullen.
    ///
    /// Als Zeichenkette und nicht als Zahl: Seriennummern von Zertifikaten sind
    /// bis zu zwanzig Byte lang, und `Int` traegt acht. Genau daran scheitert
    /// `ASN1_INTEGER_get` in der mitgelieferten Lesebibliothek, weshalb die
    /// Seriennummer hier neu gelesen wird statt von dort uebernommen.
    static func integerHex(_ element: Element) throws -> String {
        guard element.tag == integer else { throw Failure.unexpectedTag(element.tag) }
        var bytes = element.content
        guard !bytes.isEmpty else { throw Failure.malformedInteger }
        while bytes.count > 1 && bytes[0] == 0 { bytes.removeFirst() }
        return bytes.map { String(format: "%02X", $0) }.joined()
    }

    /// Ein OBJECT IDENTIFIER in Punktschreibweise.
    static func oid(_ element: Element) throws -> String {
        guard element.tag == objectIdentifier else {
            throw Failure.unexpectedTag(element.tag)
        }
        let bytes = element.content
        guard let first = bytes.first else { throw Failure.truncated }
        var parts = [String(first / 40), String(first % 40)]
        var value = 0
        for byte in bytes.dropFirst() {
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                parts.append(String(value))
                value = 0
            }
        }
        return parts.joined(separator: ".")
    }

    /// Eine UTCTime oder GeneralizedTime als `Date`.
    ///
    /// UTCTime traegt zwei Jahresstellen. Die Auslegung folgt RFC 5280: 50 bis 99
    /// heisst 19xx, 00 bis 49 heisst 20xx.
    static func time(_ element: Element) throws -> Date {
        guard let text = String(bytes: element.content, encoding: .ascii) else {
            throw Failure.malformedTime("nicht ASCII")
        }
        let digits = text.prefix { $0.isNumber }
        var stamp = String(digits)
        switch element.tag {
        case utcTime:
            guard stamp.count >= 10 else { throw Failure.malformedTime(text) }
            let twoDigitYear = Int(stamp.prefix(2)) ?? 0
            let century = twoDigitYear >= 50 ? "19" : "20"
            stamp = century + stamp
        case generalizedTime:
            guard stamp.count >= 12 else { throw Failure.malformedTime(text) }
        default:
            throw Failure.unexpectedTag(element.tag)
        }
        // Sekunden sind in UTCTime freigestellt.
        if stamp.count == 12 { stamp += "00" }
        guard stamp.count >= 14 else { throw Failure.malformedTime(text) }
        stamp = String(stamp.prefix(14))

        var parsed = DateComponents()
        func number(_ range: Range<Int>) -> Int? {
            let start = stamp.index(stamp.startIndex, offsetBy: range.lowerBound)
            let end = stamp.index(stamp.startIndex, offsetBy: range.upperBound)
            return Int(stamp[start ..< end])
        }
        parsed.year = number(0 ..< 4)
        parsed.month = number(4 ..< 6)
        parsed.day = number(6 ..< 8)
        parsed.hour = number(8 ..< 10)
        parsed.minute = number(10 ..< 12)
        parsed.second = number(12 ..< 14)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let date = calendar.date(from: parsed) else {
            throw Failure.malformedTime(text)
        }
        return date
    }
}
