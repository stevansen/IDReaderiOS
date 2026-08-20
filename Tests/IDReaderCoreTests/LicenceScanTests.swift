import Testing

@testable import IDReaderCore

/// Misst den Parser am gemessenen Korpus.
///
/// Der Massstab ist nicht "moeglichst viele Felder", sondern die Regel, unter der
/// diese Dokumentart ueberhaupt zulaessig ist: **falsch ist schlimmer als leer.**
/// Ein leeres Feld sieht der Benutzer und fuellt es; ein falsch gefuelltes sieht
/// er nur, wenn er genau hinschaut, und nichts dahinter kann es noch abfangen -
/// es gibt keinen Chip, keine Pruefziffer, keine Signatur.
///
/// Deshalb zwei getrennte Tests. Der erste laesst kein einziges falsches Feld
/// durch und schlaegt fehl, sobald eines auftaucht. Der zweite haelt fest, wie
/// viel ueberhaupt gefunden wird, und hindert daran, die Trefferquote still
/// wieder zu verlieren.
struct LicenceScanTests {

    /// Ein Feld des Ergebnisses, benannt und mit seinem Sollwert.
    private struct Field {
        let name: String
        let actual: String?
        let expected: Set<String>

        var isBlank: Bool { (actual ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        var isRight: Bool { !isBlank && expected.contains(actual!) }
        var isWrong: Bool { !isBlank && !expected.contains(actual!) }
    }

    private func fields(_ shot: LicenceScanCorpus.Shot) -> [Field] {
        let want = LicenceScanCorpus.expected(for: shot.name)
        let got = LicenceScan.read(shot.text)
        return [
            Field(name: "1  Nachname", actual: got.surname, expected: [want.surname]),
            Field(name: "2  Vorname", actual: got.givenNames, expected: [want.givenNames]),
            Field(name: "3  Geburtsdatum", actual: got.dateOfBirth, expected: [want.dateOfBirth]),
            Field(name: "3  Geburtsort", actual: got.placeOfBirth, expected: [want.placeOfBirth]),
            Field(name: "4a Ausgestellt", actual: got.dateOfIssue, expected: [want.dateOfIssue]),
            Field(name: "4b Gueltig bis", actual: got.dateOfExpiry, expected: [want.dateOfExpiry]),
            Field(
                name: "4c Stelle",
                actual: got.issuingAuthority,
                expected: [want.issuingAuthority]
            ),
            Field(name: "5  Nummer", actual: got.number, expected: want.number),
            Field(name: "9  Klassen", actual: got.categories, expected: [want.categories]),
        ]
    }

    /// Kein Feld darf einen falschen Wert tragen.
    ///
    /// Alle Verstoesse werden gesammelt und gemeinsam gemeldet: einen nach dem
    /// anderen zu beheben, wenn schon der naechste danebensteht, kostet nur
    /// Durchlaeufe.
    @Test("erfindet keine Werte")
    func inventsNoValues() {
        let violations = LicenceScanCorpus.shots.flatMap { shot in
            fields(shot)
                .filter(\.isWrong)
                .map { "\(shot.name) \($0.name): '\($0.actual!)' statt \($0.expected.sorted())" }
                .filter { !LicenceScanTests.unavoidable.contains($0) }
        }

        // Comment(rawValue:) statt eines Literals: die Meldung entsteht erst
        // beim Lauf, und ohne sie stuende im Bericht nur "violations ist nicht
        // leer" - ausgerechnet der Test, der genau sagen soll, welches Feld
        // welchen falschen Wert traegt.
        #expect(
            violations.isEmpty,
            Comment(rawValue: "Falsche Werte - schlimmer als leere Felder:\n"
                + violations.map { "  \($0)" }.joined(separator: "\n"))
        )
    }

    /// Wie viel der Parser findet.
    ///
    /// Die Schranke ist bewusst eine Zahl und keine Liste einzelner Erwartungen:
    /// welches Feld auf welcher Aufnahme durchkommt, haengt an Kleinigkeiten der
    /// Erkennung und soll sich aendern duerfen. Dass es insgesamt weniger wird,
    /// soll auffallen.
    @Test("findet genug")
    func findsEnough() {
        var report = ""
        var right = 0
        var blank = 0
        var wrong = 0

        for shot in LicenceScanCorpus.shots {
            report += "=== \(shot.name) ===\n"
            for field in fields(shot) {
                let verdict: String
                if field.isRight {
                    verdict = "ok    "
                    right += 1
                } else if field.isBlank {
                    verdict = "leer  "
                    blank += 1
                } else {
                    verdict = "FALSCH"
                    wrong += 1
                }
                report += "  \(verdict) \(field.name) = \(field.actual ?? "-")\n"
            }
        }

        let total = right + blank + wrong
        #expect(
            right >= LicenceScanTests.atLeastRight,
            Comment(rawValue: "Nur \(right) von \(total) Feldern richtig, erwartet mindestens "
                + "\(LicenceScanTests.atLeastRight)\n\(report)")
        )
    }

    /// Untergrenze fuer die Trefferquote ueber alle acht Aufnahmen.
    ///
    /// Wird angehoben, wenn der Parser besser wird - nie gesenkt, um einen Test
    /// gruen zu bekommen. 72 von 72 sind an diesem Korpus nicht zu erreichen: eine
    /// Aufnahme fuehrt die Klassen ueberhaupt nicht im erkannten Text, und zwei
    /// Felder sind auf Zeichenebene verlesen.
    private static let atLeastRight = 69

    /// Zwei Falschwerte, gegen die kein Parser hilft.
    ///
    /// Beide sind Verlesungen der Texterkennung selbst, keine Fehlgriffe der
    /// Auswertung, und beide sind aus dem gelesenen Text heraus nicht als falsch zu
    /// erkennen:
    ///
    /// - In der Nummer wurde ein `B` als `8` gelesen. Beide Lesarten haben die
    ///   zulaessige Bauform, und die Karte fuehrt keine Pruefziffer. Dieselbe Karte
    ///   wird auf zwei anderen Aufnahmen richtig gelesen.
    /// - Im Vornamen fiel ein Buchstabe aus. `SEBASTIN` ist kein gebraeuchlicher
    ///   Name, aber ein Parser, der Namen gegen eine Liste prueft, waere schlimmer
    ///   als das Uebel - er wuerde seltene Namen verwerfen.
    ///
    /// Genau dafuer sind alle Felder bearbeitbar und traegt der Bildschirm den
    /// Hinweis, jedes Feld gegen das Dokument zu halten. Die Liste steht hier,
    /// damit ein **neuer** Falschwert den Test trotzdem sofort umwirft.
    private static let unavoidable: Set<String> = [
        "A1 5  Nummer: 'U19748315M' statt [\"U1974B315M\"]",
        "B3 2  Vorname: 'SEBASTIN' statt [\"SEBASTIAN\"]",
    ]
}
