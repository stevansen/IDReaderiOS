import Foundation

/// Der Schluessel, mit dem sich der Chip oeffnen laesst.
///
/// Die beiden Dokumentarten unterscheiden sich genau hier. Die CIE 3.0 traegt
/// die CAN aufgedruckt auf der Vorderseite; ein Reisepass hat keine, dort wird
/// der Schluessel aus drei Feldern der maschinenlesbaren Zone gebildet.
///
/// Alles andere am Lesevorgang ist gleich - Datengruppen, Echtheitspruefung und
/// Chip-Authentisierung folgen bei beiden ICAO 9303.
public enum AccessKey: Sendable, Equatable {
    /// Sechs Ziffern von der Kartenvorderseite.
    case can(String)

    /// MRZ-Schluessel eines Reisepasses.
    ///
    /// `dateOfBirth` und `dateOfExpiry` sind sechsstellig als JJMMTT, so wie sie
    /// in der MRZ stehen - **ohne** Pruefziffer. `documentNumber` ebenfalls ohne
    /// Pruefziffer; die drei Pruefziffern rechnet die Schluesselableitung selbst
    /// aus. Wer sie mitgibt, erzeugt einen falschen Schluessel.
    case mrz(documentNumber: String, dateOfBirth: String, dateOfExpiry: String)

    public var isValid: Bool {
        switch self {
        case let .can(can):
            return can.count == AccessKey.canLength && can.allSatisfy(\.isNumber)
        case let .mrz(number, birth, expiry):
            return !number.isEmpty
                && number.count <= AccessKey.documentNumberLength
                && number.allSatisfy { $0.isLetter || $0.isNumber }
                && AccessKey.isMrzDate(birth)
                && AccessKey.isMrzDate(expiry)
        }
    }

    /// Laenge der CAN auf der CIE 3.0.
    public static let canLength = 6

    /// Feldbreite der Dokumentnummer in der MRZ.
    ///
    /// Laengere Nummern laufen laut ICAO 9303 in das Feld fuer optionale Daten
    /// ueber; fuer das TD3-Format der Paesse ist dieser Ueberlauf in der Praxis
    /// nicht verlaesslich lesbar. Italienische Paesse haben zwei Buchstaben und
    /// sieben Ziffern, passen also genau.
    public static let documentNumberLength = 9

    /// Stellen, die der Benutzer je Datum eingibt: TTMMJJJJ.
    public static let dateInputLength = 8

    private static let mrzDateLength = 6

    /// Ein Geburtsdatum kann weit zurueckliegen, ein Ablaufdatum weit
    /// vorausliegen. Die Spanne ist absichtlich weit - sie soll Tippfehler in
    /// der Jahrhundertstelle abfangen, nicht Lebensalter bewerten.
    private static let plausibleYears = 1900...2100

    /// Rechnet eine Eingabe TTMMJJJJ in das MRZ-Format JJMMTT um.
    ///
    /// Der Benutzer gibt das Datum so ein, wie es auf der Datenseite steht,
    /// nicht in der Reihenfolge der MRZ. Das Umsortieren im Kopf ist genau die
    /// Art Fehler, die man beim Abtippen eines Ausweises nicht braucht - und ein
    /// falsches Datum sieht hinterher wie ein falscher Pass aus.
    ///
    /// - Returns: JJMMTT, oder nil wenn die Eingabe kein plausibles Datum ist.
    public static func toMrzDate(_ input: String) -> String? {
        guard input.count == dateInputLength, input.allSatisfy(\.isNumber) else { return nil }
        let digits = Array(input)
        let day = String(digits[0..<2])
        let month = String(digits[2..<4])
        let year = String(digits[4..<8])
        guard let d = Int(day), let m = Int(month), let y = Int(year) else { return nil }
        guard (1...31).contains(d), (1...12).contains(m), plausibleYears.contains(y) else {
            return nil
        }
        return String(year.dropFirst(2)) + month + day
    }

    /// Sechs Ziffern, Monat und Tag im moeglichen Bereich.
    private static func isMrzDate(_ value: String) -> Bool {
        guard value.count == mrzDateLength, value.allSatisfy(\.isNumber) else { return false }
        let digits = Array(value)
        guard let month = Int(String(digits[2..<4])), let day = Int(String(digits[4..<6])) else {
            return false
        }
        return (1...12).contains(month) && (1...31).contains(day)
    }
}

/// Was der Benutzer beim Pass eintippt, unveraendert.
///
/// Getrennt von ``AccessKey/mrz(documentNumber:dateOfBirth:dateOfExpiry:)``,
/// weil die Eingabe eine andere Form hat als der Schluessel: der Benutzer gibt
/// die Daten als TTMMJJJJ ein, wie sie auf der Datenseite stehen. Die Umrechnung
/// passiert genau einmal, in ``accessKey``.
public struct PassportInput: Sendable, Equatable {
    public var documentNumber: String
    /// Geburtsdatum als TTMMJJJJ.
    public var dateOfBirth: String
    /// Ablaufdatum als TTMMJJJJ.
    public var dateOfExpiry: String

    public init(documentNumber: String = "", dateOfBirth: String = "", dateOfExpiry: String = "") {
        self.documentNumber = documentNumber
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
    }

    /// Der fertige Schluessel, oder nil solange die Eingabe unvollstaendig oder
    /// unplausibel ist.
    public var accessKey: AccessKey? {
        guard let birth = AccessKey.toMrzDate(dateOfBirth),
              let expiry = AccessKey.toMrzDate(dateOfExpiry) else { return nil }
        let number = documentNumber.trimmingCharacters(in: .whitespaces).uppercased()
        let key = AccessKey.mrz(documentNumber: number, dateOfBirth: birth, dateOfExpiry: expiry)
        return key.isValid ? key : nil
    }

    public var isValid: Bool { accessKey != nil }
}
