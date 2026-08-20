import Foundation

/// Zieht den Zugangsschluessel aus erkanntem MRZ-Text.
///
/// Gebraucht wird nur die **zweite** Zeile der MRZ. Dokumentnummer, Geburtsdatum
/// und Ablaufdatum stehen alle drei dort, und jedes Feld traegt eine Pruefziffer
/// nach ICAO 9303. Die erste Zeile enthaelt nur Name und Staat - fuer den
/// Schluessel unbrauchbar und ohne Pruefziffer.
///
/// Das ist der Grund, ueberhaupt die MRZ zu fotografieren und nicht die
/// Datenseite: **das Ergebnis laesst sich verifizieren.** Stimmen alle drei
/// Pruefziffern, ist die Erkennung nachweislich richtig. Stimmt eine nicht, wird
/// nichts uebernommen - lieber tippt der Benutzer, als dass die App mit einer
/// verlesenen Ziffer einen echten Pass als nicht oeffenbar meldet.
///
/// Bewusst **kein** Reparaturversuch bei typischen Verwechslungen (O/0, I/1,
/// S/5). Eine Pruefziffer ist modulo 10: eine falsch geratene Ersetzung geht mit
/// zehnprozentiger Wahrscheinlichkeit trotzdem durch, und dann steht eine falsche
/// Dokumentnummer im Feld, die niemand mehr hinterfragt.
public enum MrzScan {

    /// Sucht in beliebigem erkannten Text einen gueltigen Schluessel.
    ///
    /// Der Text wird von allem befreit, was nicht zum MRZ-Zeichensatz gehoert.
    /// Danach wandert ein Fenster durch die Zeichenkette; als Treffer gilt die
    /// erste Stelle, an der alle drei Pruefziffern aufgehen.
    ///
    /// Ein Fehltreffer an falscher Position muesste drei unabhaengige Pruefziffern
    /// gleichzeitig erfuellen und zwei plausible Datumsangaben ergeben. Das ist
    /// unwahrscheinlich genug, um die Position nicht zusaetzlich verankern zu
    /// muessen.
    public static func findKey(_ recognisedText: String) -> AccessKey? {
        let cleaned = Array(recognisedText.uppercased().filter { mrzAlphabet.contains($0) })
        guard cleaned.count >= fieldsEnd else { return nil }

        for start in 0...(cleaned.count - fieldsEnd) {
            if let key = parse(cleaned, at: start) { return key }
        }
        return nil
    }

    /// Prueft eine einzelne Position. nil, wenn dort keine gueltige Zeile beginnt.
    private static func parse(_ line: [Character], at start: Int) -> AccessKey? {
        func part(_ from: Int, _ to: Int) -> String {
            String(line[(start + from)..<(start + to)])
        }

        let documentNumber = part(0, 9)
        let documentCheck = part(9, 10)
        let dateOfBirth = part(13, 19)
        let birthCheck = part(19, 20)
        let dateOfExpiry = part(21, 27)
        let expiryCheck = part(27, 28)

        guard checkDigitMatches(documentNumber, documentCheck),
              checkDigitMatches(dateOfBirth, birthCheck),
              checkDigitMatches(dateOfExpiry, expiryCheck)
        else { return nil }

        // Die Fuellzeichen gehoeren zur Feldbreite, nicht zur Nummer. Die
        // Schluesselableitung fuellt kurze Nummern selbst wieder auf.
        var number = documentNumber
        while number.hasSuffix(String(filler)) { number.removeLast() }
        guard !number.isEmpty, !number.contains(filler) else { return nil }

        let key = AccessKey.mrz(
            documentNumber: number,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
        return key.isValid ? key : nil
    }

    /// Pruefziffer nach ICAO 9303: Gewichte 7-3-1 im Wechsel, Ziffern zaehlen
    /// ihren Wert, Buchstaben A bis Z zaehlen 10 bis 35, das Fuellzeichen zaehlt
    /// null. Die Summe modulo zehn ergibt die Ziffer.
    public static func checkDigitMatches(_ value: String, _ expected: String) -> Bool {
        guard expected.count == 1, let digit = expected.first, digit.isASCII, digit.isNumber else {
            return false
        }

        var sum = 0
        for (index, character) in value.enumerated() {
            let weight = weights[index % weights.count]
            let amount: Int
            if let ascii = character.asciiValue, character.isNumber {
                amount = Int(ascii - 48)
            } else if let ascii = character.asciiValue, character.isLetter,
                      character.isUppercase, ascii >= 65, ascii <= 90 {
                amount = Int(ascii - 65) + letterOffset
            } else if character == filler {
                amount = 0
            } else {
                return false
            }
            sum += amount * weight
        }
        return sum % modulus == Int(String(digit))!
    }

    private static let filler: Character = "<"
    private static let mrzAlphabet: Set<Character> = {
        var set = Set<Character>("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(filler)
        return set
    }()
    private static let weights = [7, 3, 1]
    private static let letterOffset = 10
    private static let modulus = 10

    /// Bis hierhin reichen die Felder, die gebraucht werden - Dokumentnummer,
    /// Geburtsdatum, Ablaufdatum samt ihrer drei Pruefziffern. Der Rest der Zeile
    /// (optionale Daten und die Gesamtpruefziffer) wird nicht verlangt, damit ein
    /// am Rand abgeschnittenes Foto noch auswertbar bleibt.
    private static let fieldsEnd = 28
}
