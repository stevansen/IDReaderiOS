import Foundation
import NFCPassportReaderCAN

/// Wegmarken eines Lesevorgangs, für den Fall, dass er scheitert.
///
/// ## Warum das nötig wurde
///
/// Zwei Rückmeldungen aus dem Betatest sagten „Lesen fehlgeschlagen", und beide
/// waren nicht zu deuten. Die CIE meldete „PACE failed", der Reisepass ein
/// nacktes `SW 6985`. Aus dem Quelltext war beides nicht zu unterscheiden von
/// einem falsch eingetippten Schlüssel — und der Benutzer hatte ihn schon von
/// Hand eingegeben.
///
/// Der Grund für die Blindheit steckt im Ablauf der Lesebibliothek: sie fängt
/// den PACE-Fehler ab, protokolliert ihn ins Systemlog und macht mit BAC weiter.
/// Wer das Gerät nicht am Kabel hat, sieht davon nichts.
///
/// Diese Klasse holt zurück, was ohne Kabel zu haben ist. Sie hängt am
/// **vorhandenen** `PassportReaderTrackingDelegate` der Bibliothek — kein
/// weiterer Eingriff in fremden Code.
///
/// ## Was darin steht, und was nicht
///
/// Wegmarken und Verfahrensangaben: welche Stufe erreicht wurde, welche
/// PACE-Kennung der Chip anbietet, welche Kurve. **Keine** Personendaten und
/// nicht der Zugangsschlüssel. Der Text wird kopiert und verschickt; er muss
/// jemandem in die Hand gegeben werden können, ohne dass daran etwas hängt.
final class ReadTrail: PassportReaderTrackingDelegate {

    private var marks: [String] = []
    private let lock = NSLock()

    /// Die Marken als eine Zeile, in der Reihenfolge, in der sie anfielen.
    var summary: String {
        lock.lock()
        defer { lock.unlock() }
        return marks.isEmpty ? "keine Wegmarke" : marks.joined(separator: " → ")
    }

    private func add(_ mark: String) {
        lock.lock()
        marks.append(mark)
        lock.unlock()
        // Dieselben Marken auch in das Protokoll, damit dort zu sehen ist, in
        // welcher Stufe welches APDU lief.
        ReadLog.shared.add("· \(mark)")
    }

    func reset() {
        lock.lock()
        marks.removeAll()
        lock.unlock()
    }

    // -----------------------------------------------------------------------

    func nfcTagDetected() { add("Chip erkannt") }

    /// Was der Chip über sich sagt, bevor irgendein Schlüssel im Spiel ist.
    ///
    /// Die entscheidende Auskunft: PACE ist ein Rahmen, und welches Verfahren
    /// darin läuft, sagt die Kennung. Steht hier eine, die auf brainpool zeigt,
    /// hängt der Lesevorgang an OpenSSL; steht keine, ist es kein PACE-Chip und
    /// eine CIE 3.0 dann auch nicht.
    func readCardAccess(cardAccess: CardAccess) {
        let teile = cardAccess.securityInfos.map { info -> String in
            let kennung = info.getObjectIdentifier()
            guard let pace = info as? PACEInfo else { return kennung }
            // Die drei Werte, an denen der Ablauf haengt.
            //
            // Der Verfahrensname bestimmt, ob mit DH oder ECDH gerechnet wird;
            // die Parameterkennung, ueber welcher Gruppe oder Kurve. Passen die
            // beiden nicht zueinander - etwa DH als Verfahren und eine
            // brainpool-Kurve als Parameter -, dann rechnet die Bibliothek mit
            // dem falschen Verfahren, der Chip antwortet unerwartet, und heraus
            // kommt genau das `InvalidASN1Value`, das am Geraet zu sehen war.
            //
            // Genau diese Unstimmigkeit ist von aussen nicht anders zu sehen.
            let parameter = pace.getParameterId().map(String.init) ?? "keine"
            // `description()` der Bibliothek ist `internal` - also selbst
            // benennen, statt einen fuenften Eingriff in fremden Code dafuer zu
            // machen.
            let abbildung: String
            switch try? pace.getMappingType() {
            case .some(.GM): abbildung = "GM"
            case .some(.IM): abbildung = "IM"
            case .some(.CAM): abbildung = "CAM"
            default: abbildung = "Abbildung unbekannt"
            }
            return "\(kennung) v\(pace.getVersion()) Param \(parameter) \(abbildung)"
        }
        add("CardAccess gelesen (\(cardAccess.securityInfos.count)): \(teile.joined(separator: " | "))")
    }

    func paceStarted() { add("PACE begonnen") }
    func paceSucceeded() { add("PACE erfolgreich") }
    func paceFailed() { add("PACE gescheitert") }
    func bacStarted() { add("BAC begonnen") }
    func bacSucceeded() { add("BAC erfolgreich") }
    func bacFailed() { add("BAC gescheitert") }
}
