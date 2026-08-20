import Foundation

/// Zieht die CAN aus erkanntem Text der Kartenvorderseite.
///
/// Zwei Eigenschaften der CAN bestimmen alles, was hier steht.
///
/// **Es gibt keine Pruefziffer.** ICAO 9303 Teil 5, Abschnitt 3.2.3 sagt das
/// ausdruecklich: sechs Ziffern, und die Pruefung erfolge implizit durch das
/// Protokoll. Anders als bei der MRZ des Passes, wo drei Pruefziffern eine
/// Erkennung offline bestaetigen, ist jede Folge von sechs Ziffern eine
/// syntaktisch moegliche CAN. Die einzige Instanz, die eine CAN bestaetigen kann,
/// ist die Karte selbst.
///
/// **Es gibt keine Beschriftung.** Das italienische Dekret DM 23.12.2015,
/// Anlage A, fuehrt die CAN als "Zona 14 / Fronte" mit der Etikette "-" - die
/// sechs Ziffern stehen unten rechts auf der Vorderseite, in OCR-B, und nichts
/// daneben sagt, was sie sind. Eine Regel "die Zahl neben dem Wort CAN" waere auf
/// einer echten CIE also wirkungslos.
///
/// Damit bleibt die Eindeutigkeit als einziges belastbares Merkmal: eine Zahl wird
/// nur uebernommen, wenn sie die **einzige** sechsstellige im Bild ist. Auf der
/// Vorderseite trifft das zu, denn nach demselben Dekret hat dort keine andere
/// Angabe sechs Ziffern.
///
/// Gibt es mehrere Kandidaten, wird nichts uebernommen. Das ist die wichtigste
/// Entscheidung hier: eine geratene Zahl saehe im Feld genauso aus wie eine
/// richtige, und der Benutzer haette keinen Anlass, sie nachzupruefen.
///
/// Was durchkommt, ist also plausibel, nicht bewiesen. Bewiesen wird es beim
/// Lesen: mit falscher CAN oeffnet sich der Chip nicht. Schaden kann eine
/// verlesene Zahl nicht - die CAN ist nach BSI TR-03110-1, Abschnitt 2.3, ein
/// nicht sperrendes Passwort, der Chip darf sie nach Fehlversuchen nicht
/// blockieren. Ein Fehlversuch kostet einen Fehlversuch.
public enum CanScan {

    /// Ergebnis der Auswertung.
    public enum Result: Sendable, Equatable {
        /// Genau eine Zahl kommt in Frage.
        case found(String)
        /// Keine sechsstellige Zahl im Bild.
        case notFound
        /// Mehrere sechsstellige Zahlen. Absichtlich kein Rateversuch.
        case ambiguous
        /// Im Bild steht eine maschinenlesbare Zone, also die Rueckseite der
        /// Karte oder ein anderes Dokument. Nach dem Dekret steht die CAN
        /// ausschliesslich auf der Vorderseite; was auf dieser Seite an Ziffern zu
        /// finden waere, ist deshalb nicht die CAN, egal wie eindeutig es
        /// aussieht.
        case wrongSide
    }

    /// Sucht die CAN in beliebigem erkannten Text.
    ///
    /// Zeilenweise, nicht ueber den ganzen Text hinweg: die Texterkennung liefert
    /// ihre Bloecke zeilengetrennt, und zwei Zahlen aus verschiedenen Zeilen
    /// zusammenzusetzen waere geraten. Innerhalb einer Zeile werden Leerzeichen
    /// zwischen Ziffern dagegen geschlossen - eine Erkennung, die die eng
    /// gesetzten OCR-B-Ziffern in zwei Gruppen zerlegt, soll daran nicht
    /// scheitern.
    public static func find(_ recognisedText: String) -> Result {
        if recognisedText.filter({ $0 == mrzFiller }).count >= mrzFillerMinimum {
            return .wrongSide
        }

        // Dieselbe Zahl mehrfach erkannt ist kein Widerspruch, sondern
        // Bestaetigung - deshalb ueber die Werte und nicht ueber die Treffer
        // zaehlen.
        var candidates: [String] = []
        for line in recognisedText.split(separator: "\n", omittingEmptySubsequences: false) {
            let joined = digitGap.replacingAll(in: String(line), with: "")
            for match in standaloneSixDigits.allMatches(joined) where !candidates.contains(match.value) {
                candidates.append(match.value)
            }
        }

        switch candidates.count {
        case 0: return .notFound
        case 1: return .found(candidates[0])
        default: return .ambiguous
        }
    }

    /// Sechs Ziffern, die weder in einer laengeren Zahl noch in einem Wort
    /// stecken.
    ///
    /// Beide Abgrenzungen sind an Fehlern gelernt, die eine Erkennung wirklich
    /// macht:
    ///
    /// - Keine Ziffer daneben, sonst wuerden aus einem zusammengeschriebenen
    ///   Datum (01011990) sechs Ziffern herausgeschnitten.
    /// - **Kein Buchstabe daneben**, sonst zaehlt eine Ziffernfolge mitten in
    ///   einem Wort mit. Die Dokumentnummer der CIE besteht aus zwei Buchstaben,
    ///   fuenf Ziffern und zwei Buchstaben; wird das abschliessende B als 8
    ///   gelesen, dann steht in CA431278B eine sechsstellige Folge, die keine CAN
    ///   ist.
    ///
    /// Der Preis der zweiten Regel: klebt die Erkennung die Ziffern an die
    /// Landeskennung IT aus dem Sicherheitsmerkmal darueber, wird die CAN
    /// verworfen. Das ist die richtige Richtung des Irrtums - eine Ablehnung wird
    /// gemeldet und laesst sich eintippen, eine falsche Zahl im Feld nicht.
    private static let standaloneSixDigits = Pattern(
        "(?<![\\p{L}\\p{N}])\\d{\(AccessKey.canLength)}(?![\\p{L}\\p{N}])"
    )

    /// Leerraum zwischen zwei Ziffern, innerhalb einer Zeile.
    private static let digitGap = Pattern("(?<=\\d)[ \\t]+(?=\\d)")

    /// Das Fuellzeichen der maschinenlesbaren Zone. Auf der Vorderseite kommt es
    /// nicht vor, in einer MRZ dagegen in Serien - ein paar Treffer genuegen also
    /// als Nachweis, und Einzeltreffer aus Erkennungsfehlern zaehlen nicht.
    private static let mrzFiller: Character = "<"
    private static let mrzFillerMinimum = 5
}
