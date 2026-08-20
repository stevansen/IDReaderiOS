import Testing

@testable import IDReaderCore

/// Die MRZ des Passes - der einzige Schluessel, der sich offline bestaetigen
/// laesst.
struct MrzScanTests {

    /// Eine TD3-Zeile mit stimmenden Pruefziffern.
    ///
    /// Aufgebaut, nicht abgeschrieben: die Pruefziffern rechnet der Test selbst
    /// aus, damit die Vorlage nicht durch einen Tippfehler unbrauchbar wird und
    /// niemand hinterher raet, ob der Parser oder die Vorlage schuld ist.
    private func line(number: String, birth: String, expiry: String) -> String {
        let paddedNumber = number.padding(toLength: 9).replacingOccurrences(of: " ", with: "<")
        return paddedNumber + check(paddedNumber)
            + "ITA"
            + birth + check(birth) + "M"
            + expiry + check(expiry)
            + "<<<<<<<<<<<<<<"
    }

    private func check(_ value: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0
        for (index, character) in value.enumerated() {
            let amount: Int
            if let digit = character.wholeNumberValue, character.isNumber {
                amount = digit
            } else if character == "<" {
                amount = 0
            } else {
                amount = Int(character.asciiValue! - 65) + 10
            }
            sum += amount * weights[index % 3]
        }
        return String(sum % 10)
    }

    @Test("findet den Schluessel in beliebigem Text")
    func findsKeyInNoise() {
        let mrz = line(number: "YA1234567", birth: "800101", expiry: "300201")
        let text = "P<ITAROSSI<<MARIO<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" + mrz

        guard case let .mrz(number, birth, expiry)? = MrzScan.findKey(text) else {
            Issue.record("kein Schluessel gefunden")
            return
        }
        #expect(number == "YA1234567")
        #expect(birth == "800101")
        #expect(expiry == "300201")
    }

    /// Eine verlesene Ziffer wird **nicht** ausgebessert.
    ///
    /// Der Grund steht in ``MrzScan``: eine Pruefziffer ist modulo 10, eine falsch
    /// geratene Ersetzung geht mit zehnprozentiger Wahrscheinlichkeit trotzdem
    /// durch - und dann steht eine falsche Dokumentnummer im Feld, die niemand
    /// mehr hinterfragt.
    @Test("verwirft eine Zeile mit falscher Pruefziffer")
    func rejectsBadCheckDigit() {
        var mrz = Array(line(number: "YA1234567", birth: "800101", expiry: "300201"))
        // Die Pruefziffer der Dokumentnummer verbiegen.
        mrz[9] = mrz[9] == "0" ? "1" : "0"
        #expect(MrzScan.findKey(String(mrz)) == nil)
    }

    @Test("kurze Nummern behalten kein Fuellzeichen")
    func shortNumberLosesFiller() {
        let mrz = line(number: "AB12345", birth: "650902", expiry: "260902")
        guard case let .mrz(number, _, _)? = MrzScan.findKey(mrz) else {
            Issue.record("kein Schluessel gefunden")
            return
        }
        #expect(number == "AB12345")
    }

    @Test("zu kurzer Text ergibt nichts")
    func tooShort() {
        #expect(MrzScan.findKey("P<ITAROSSI") == nil)
    }
}

/// Die CAN der CIE - sechs Ziffern ohne Pruefziffer, ohne Beschriftung.
struct CanScanTests {

    @Test("eine einzige sechsstellige Zahl wird uebernommen")
    func singleCandidate() {
        #expect(CanScan.find("CA43127\nAB\n123456") == .found("123456"))
    }

    /// Dieselbe Zahl mehrfach erkannt ist kein Widerspruch, sondern Bestaetigung.
    @Test("dieselbe Zahl zweimal ist eindeutig")
    func sameNumberTwice() {
        #expect(CanScan.find("123456\n123456") == .found("123456"))
    }

    @Test("mehrere Zahlen: kein Rateversuch")
    func ambiguous() {
        #expect(CanScan.find("123456\n654321") == .ambiguous)
    }

    /// Die Dokumentnummer der CIE ist zwei Buchstaben, fuenf Ziffern, zwei
    /// Buchstaben. Wird das abschliessende B als 8 gelesen, steht in `CA431278B`
    /// eine sechsstellige Folge, die keine CAN ist.
    @Test("Ziffern in einem Wort zaehlen nicht")
    func digitsInsideAWord() {
        #expect(CanScan.find("CA431278B") == .notFound)
    }

    /// Ein zusammengeschriebenes Datum darf nicht angeschnitten werden.
    @Test("keine sechs Ziffern aus einer laengeren Zahl")
    func noSliceOfALongerNumber() {
        #expect(CanScan.find("01011990") == .notFound)
    }

    /// Eine Erkennung, die die eng gesetzten OCR-B-Ziffern in zwei Gruppen
    /// zerlegt, soll daran nicht scheitern.
    @Test("Leerraum zwischen Ziffern wird geschlossen")
    func closesDigitGap() {
        #expect(CanScan.find("123 456") == .found("123456"))
    }

    /// Nach dem Dekret steht die CAN ausschliesslich auf der Vorderseite.
    @Test("die maschinenlesbare Zone ist die falsche Seite")
    func wrongSide() {
        #expect(CanScan.find("IDITARO<<<<<<<<<<<<<<<<\n123456") == .wrongSide)
    }

    @Test("nichts im Bild")
    func nothing() {
        #expect(CanScan.find("PATENTE DI GUIDA") == .notFound)
    }
}

/// Die Umrechnung der Eingabe in den MRZ-Schluessel.
struct AccessKeyTests {

    @Test("TTMMJJJJ wird JJMMTT")
    func inputDateBecomesMrzDate() {
        #expect(AccessKey.toMrzDate("01021980") == "800201")
        #expect(AccessKey.toMrzDate("31122099") == "991231")
    }

    @Test("unplausible Eingaben ergeben nichts")
    func implausibleDates() {
        #expect(AccessKey.toMrzDate("32011980") == nil)
        #expect(AccessKey.toMrzDate("01131980") == nil)
        #expect(AccessKey.toMrzDate("01011899") == nil)
        #expect(AccessKey.toMrzDate("0101198") == nil)
        #expect(AccessKey.toMrzDate("0101198X") == nil)
    }

    @Test("die CAN ist genau sechsstellig und numerisch")
    func canValidity() {
        #expect(AccessKey.can("123456").isValid)
        #expect(!AccessKey.can("12345").isValid)
        #expect(!AccessKey.can("1234567").isValid)
        #expect(!AccessKey.can("12345A").isValid)
    }

    @Test("die Passeingabe wird erst mit allen drei Feldern ein Schluessel")
    func passportInput() {
        var input = PassportInput()
        #expect(input.accessKey == nil)
        input.documentNumber = "YA1234567"
        #expect(input.accessKey == nil)
        input.dateOfBirth = "01021980"
        #expect(input.accessKey == nil)
        input.dateOfExpiry = "01022030"
        #expect(input.accessKey == .mrz(
            documentNumber: "YA1234567",
            dateOfBirth: "800201",
            dateOfExpiry: "300201"
        ))
    }
}
