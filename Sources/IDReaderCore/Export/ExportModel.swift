import Foundation

/// Eine Zeile der lesbaren Ausgabe.
public struct ExportRow: Sendable, Equatable, Identifiable {
    public let label: String
    public let value: String
    public var id: String { label }

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// Ein Abschnitt der lesbaren Ausgabe: Ueberschrift und Zeilen.
public struct ExportSection: Sendable, Equatable, Identifiable {
    public let title: String
    public let rows: [ExportRow]
    public var id: String { title }

    public init(title: String, rows: [ExportRow]) {
        self.title = title
        self.rows = rows
    }
}

/// Ein Datensatz in der Gliederung der lesbaren Ausgabe.
///
/// Dient zwei Zwecken: aus ihm entsteht der Text, der geteilt wird, und aus
/// demselben Objekt zeichnet die Vorschau ihre Tabelle. Damit koennen die beiden
/// nicht auseinanderlaufen.
public struct ExportRecord: Sendable, Equatable {
    public let title: String
    public let subtitle: String
    public let sections: [ExportSection]

    /// Vorbehalt ueber dem Datensatz, oder nil.
    ///
    /// Steht bewusst nicht als Zeile zwischen den Feldern, sondern darueber: er
    /// gilt fuer alles, was folgt. Wer im Einsatzbericht nur die Namenszeile
    /// liest, soll trotzdem sehen, dass niemand diese Angaben geprueft hat.
    public let notice: String?

    public init(title: String, subtitle: String, sections: [ExportSection], notice: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
        self.notice = notice
    }

    /// Anzahl der Felder, die tatsaechlich hinausgehen. Steht im Teilen-Schirm.
    public var fieldCount: Int {
        sections.reduce(0) { $0 + $1.rows.count }
    }
}
