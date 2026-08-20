import Foundation

/// Duenne Huelle um `NSRegularExpression`.
///
/// Bewusst nicht die Swift-eigenen `Regex`-Literale: die Muster hier leben von
/// Vor- und Ruecksichten (`(?<![\p{L}\p{N}])`), und die sind bei ICU seit Jahren
/// da und geprueft. Ein Muster, das je nach Sprachfassung anders oder gar nicht
/// uebersetzt, ist an dieser Stelle die falsche Art Ueberraschung - hier
/// entscheiden die Muster darueber, ob eine erfundene Dokumentnummer in einem
/// Bericht landet.
///
/// Die Namen der Operationen folgen dem Kotlin-Original (`matches`,
/// `containsMatch`, `firstMatch`, `allMatches`), damit sich die portierten
/// Stellen Zeile fuer Zeile gegen das Original halten lassen.
/// `@unchecked Sendable`: `NSRegularExpression` ist laut Dokumentation
/// threadsicher fuer die Suche, traegt die Kennzeichnung aber nicht. Die Muster
/// hier sind ausserdem Konstanten - nach dem Init aendert sich nichts mehr.
struct Pattern: @unchecked Sendable {
    private let expression: NSRegularExpression

    init(_ pattern: String) {
        // Ein Muster in dieser Datei ist eine Konstante im Quelltext. Faellt es
        // um, ist das kein Laufzeitfall, sondern ein Programmierfehler, der beim
        // ersten Start auffallen soll.
        expression = try! NSRegularExpression(pattern: pattern)
    }

    /// Trifft das Muster die **ganze** Zeichenkette? (Kotlin: `matches`)
    func matches(_ string: String) -> Bool {
        guard let match = firstMatch(string) else { return false }
        return match.range == string.startIndex..<string.endIndex
    }

    /// Kommt das Muster irgendwo vor? (Kotlin: `containsMatchIn`)
    func containsMatch(_ string: String) -> Bool {
        firstMatch(string) != nil
    }

    func firstMatch(_ string: String) -> Match? {
        let full = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let result = expression.firstMatch(in: string, options: [], range: full) else {
            return nil
        }
        return Match(result: result, string: string)
    }

    func allMatches(_ string: String) -> [Match] {
        let full = NSRange(string.startIndex..<string.endIndex, in: string)
        return expression.matches(in: string, options: [], range: full)
            .map { Match(result: $0, string: string) }
    }

    struct Match {
        let range: Range<String.Index>
        let value: String
        private let groups: [String?]

        init(result: NSTextCheckingResult, string: String) {
            range = Range(result.range, in: string)!
            value = String(string[range])
            groups = (0..<result.numberOfRanges).map { index in
                guard let r = Range(result.range(at: index), in: string) else { return nil }
                return String(string[r])
            }
        }

        /// Gruppe `index`; 0 ist der gesamte Treffer.
        subscript(_ index: Int) -> String? {
            groups.indices.contains(index) ? groups[index] : nil
        }
    }
}

extension String {
    /// Zeilen ohne Leerraum an den Raendern, leere weggelassen.
    var nonEmptyTrimmedLines: [String] {
        split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension Pattern {
    /// Alle Treffer ersetzen. (Kotlin: `String.replace(Regex, String)`)
    ///
    /// Aus Teilstuecken zusammengesetzt statt an der Zeichenkette geaendert:
    /// `String.Index` gilt nur fuer die Fassung, aus der er stammt, und eine
    /// Ersetzung mit abweichender Laenge macht alle folgenden ungueltig.
    func replacingAll(in string: String, with replacement: String) -> String {
        var result = ""
        var cursor = string.startIndex
        for match in allMatches(string) {
            result += string[cursor..<match.range.lowerBound]
            result += replacement
            cursor = match.range.upperBound
        }
        result += string[cursor...]
        return result
    }
}
