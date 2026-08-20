import Foundation

/// Zerlegt zweisprachige Orts- und Adressangaben aus DG11.
///
/// In Suedtirol stehen Orte und Strassen auf der Karte zweisprachig, getrennt
/// durch einen Schraegstrich - italienisch zuerst (amtlich), deutsch danach:
///
///     VALDAGNO DI TRENTO/ALDEIN, TN
///     VIA C.AUGUSTA/C.-AUGUSTA-STR., 16/B, BOLZANO/BOZEN, BZ
///
/// Der Schraegstrich ist dabei nicht eindeutig: "16/B" ist eine Hausnummer und
/// darf nicht zerlegt werden. Getrennt wird deshalb nur, wenn ein Abschnitt genau
/// einen Schraegstrich enthaelt und auf beiden Seiten mindestens zwei Buchstaben
/// stehen. Damit bleiben "16/B", "1/A" und "12/14" unangetastet, waehrend
/// "BOLZANO/BOZEN" auseinandergenommen wird.
///
/// Im Zweifel bleibt der Abschnitt unveraendert. Lieber beide Sprachen zeigen als
/// die falsche wegwerfen.
public enum BilingualText {

    /// - Parameter preferGerman: true bei deutscher App-Sprache; sonst wird
    ///   durchgehend die italienische, amtliche Fassung genommen.
    public static func pick(_ raw: String?, preferGerman: Bool) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let joined = raw
            .split(separator: segmentSeparator, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { pickSegment($0, preferGerman: preferGerman) }
            .joined(separator: ", ")

        return joined.trimmingCharacters(in: .whitespaces).isEmpty ? nil : joined
    }

    private static func pickSegment(_ segment: String, preferGerman: Bool) -> String {
        let parts = segment.split(separator: languageSeparator, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return segment }

        let italian = parts[0].trimmingCharacters(in: .whitespaces)
        let german = parts[1].trimmingCharacters(in: .whitespaces)
        guard looksLikeWord(italian), looksLikeWord(german) else { return segment }

        return preferGerman ? german : italian
    }

    /// Eine Hausnummer ist kein Wort - dafuer braucht es Buchstaben.
    private static func looksLikeWord(_ value: String) -> Bool {
        value.filter(\.isLetter).count >= minLetters
    }

    private static let segmentSeparator: Character = ","
    private static let languageSeparator: Character = "/"
    private static let minLetters = 2
}
