import Testing

@testable import IDReaderCore

/// Faelle, die im gemessenen Korpus nicht vorkommen.
///
/// Acht Aufnahmen von zwei Karten zeigen nicht alles. Was hier steht, stammt aus
/// einer gegnerischen Durchsicht, die den Parser gegen abgewandelte Fassungen
/// dieser Aufnahmen laufen liess - Zeilen weggelassen, Bloecke verschoben - und
/// dabei Loecher fand, die zwei Karten nie aufgedeckt haetten.
///
/// Die Eingaben sind erfunden, aber in der Bauform der gemessenen: dieselben
/// Etiketten, dieselbe Zeilenfuehrung.
struct LicenceScanEdgeTests {

    /// Italienische Namenszusaetze.
    ///
    /// `DI` und `GUIDA` standen in der Liste der Kartenaufdrucke und schlossen
    /// damit jeden Namen mit `DI` aus. Der Nachname fiel weg, und das Feld nahm
    /// sich stattdessen den Vornamen - zwei Felder falsch aus einem Wort.
    @Test func namePrefixSurvives() {
        let fields = LicenceScan.read(
            """
            PATENTE DI GUIDA
            1. DI STEFANO
            2. GIUSEPPE
            5. AB1234567C
            """
        )
        #expect(fields.surname == "DI STEFANO")
        #expect(fields.givenNames == "GIUSEPPE")
    }

    /// Der typografische Apostroph darf den Namen nicht veraendern.
    @Test func apostropheStays() {
        let fields = LicenceScan.read("1. D\u{2019}ANGELO\n2. LUCA")
        #expect(fields.surname == "D'ANGELO")
    }

    /// Die Klassen A1 und B1 kommen als AI und BI an.
    ///
    /// Ohne Rueckdrehung faellt wegen der Alles-oder-nichts-Regel nicht nur die
    /// eine Klasse weg, sondern das ganze Feld.
    @Test func misreadCategoryDigits() {
        #expect(LicenceScan.read("9. AI B").categories == "A1 B")
    }

    /// Kleingeschriebener Kleindruck ist keine Fahrerlaubnis.
    @Test func smallPrintIsNoCategory() {
        #expect(LicenceScan.read("9. a").categories == nil)
    }

    /// Aus Satzzeichen laesst sich keine Dokumentnummer zusammensetzen.
    ///
    /// Die zerlesene Zeile `G0. 07/O4/2031` ergab frueher `G007O42031`: zehn
    /// Zeichen, zwei Buchstaben, acht Ziffern - eine erfundene Nummer, der niemand
    /// ansieht, dass es sie nicht gibt.
    @Test func noNumberFromPunctuation() {
        #expect(LicenceScan.read("5.\nG0. 07/O4/2031").number == nil)
    }

    /// Ein vierstelliges Jahr gehoert nie ins Geburtsdatum.
    ///
    /// Fehlt die Geburtszeile, griff Feld 3 sonst nach dem Ausstellungsdatum und
    /// lieferte ein Geburtsjahr 2015.
    @Test func birthDateTakesNoIssueDate() {
        let fields = LicenceScan.read("3.\n4a. 08/06/2015 4c. MIT-UCO\n4b. 02/09/2026")
        #expect(fields.dateOfBirth == nil)
        #expect(fields.dateOfIssue == "08.06.2015")
        #expect(fields.dateOfExpiry == "02.09.2026")
    }

    /// Stehen Ausstellung und Ablauf verkehrt herum, ist eines falsch zugeordnet.
    ///
    /// Dann gelten beide als nicht gefunden und werden aus der Reihenfolge neu
    /// bestimmt - die einzige feste Beziehung, die diese Karte hergibt.
    @Test func swappedDatesGetStraightened() {
        let fields = LicenceScan.read("4a. 02/09/2026\n4b. 08/06/2015")
        #expect(fields.dateOfIssue == "08.06.2015")
        #expect(fields.dateOfExpiry == "02.09.2026")
    }

    /// Das zweistellige Geburtsjahr richtet sich nach der Ausstellung.
    ///
    /// `29` ergaebe mit fester Jahrhundertgrenze 2029 - ein Datum in der Zukunft,
    /// und Jahre nach der Ausstellung der Karte. Niemand wird nach seiner
    /// Fahrerlaubnis geboren.
    @Test func birthYearLiesBeforeIssue() {
        let fields = LicenceScan.read(
            "3. 14/05/29 ROMA (RM)\n4a. 08/06/2015 4c. MIT-UCO\n4b. 02/09/2026"
        )
        #expect(fields.dateOfBirth == "14.05.1929")
    }

    /// Ein Vorname wird kein Geburtsort, auch wenn er in Versalien steht.
    @Test func givenNameIsNoBirthPlace() {
        let fields = LicenceScan.read("3.\nGIUSEPPE\n1. DI STEFANO")
        #expect(fields.placeOfBirth == nil)
    }

    /// Die aeltere Karte einer Provinz wird genauso gelesen.
    @Test func olderProvincialCard() {
        let fields = LicenceScan.read(
            """
            1. ROSSI
            2. MARIA TERESA
            3. 21/07/76 TRENTO (TN)
            4a. 12/03/2009 4c. MC-TN
            4b. 21/07/2019
            5. TN1234567A
            9. B
            """
        )
        #expect(fields.surname == "ROSSI")
        #expect(fields.givenNames == "MARIA TERESA")
        #expect(fields.dateOfBirth == "21.07.1976")
        #expect(fields.placeOfBirth == "TRENTO (TN)")
        #expect(fields.issuingAuthority == "MC-TN")
        #expect(fields.number == "TN1234567A")
        #expect(fields.categories == "B")
    }
}
