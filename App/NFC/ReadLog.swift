import Foundation
import NFCPassportReaderCAN

/// Das Protokoll eines Lesevorgangs, zum Verschicken.
///
/// ## Wozu
///
/// Ein Fehlschlag am Gerät ist ohne Kabel nicht zu untersuchen. Die
/// Fehlermeldung sagt *was*, die Wegmarken sagen *wie weit* — aber nicht, welche
/// Befehle der Chip bekommen und was er geantwortet hat. Genau daran hing die
/// Suche nach dem PACE-Fehler mehrere Bauten lang.
///
/// Dieses Protokoll wird **nicht** geschrieben, um dauerhaft etwas
/// aufzuzeichnen. Es lebt im Arbeitsspeicher, hält den letzten Lesevorgang, wird
/// bei jedem neuen geleert und geht mit der App verloren. Es steht in keiner
/// Datei und in keiner Sicherung.
///
/// ## Was darin steht
///
/// Vor dem Aufbau der gesicherten Verbindung der vollständige APDU-Verkehr:
/// Applet-Auswahl, `EF.CardAccess`, der PACE-Austausch. Das sind flüchtige
/// Schlüssel und Nonces — keine Personendaten und nicht der Zugangsschlüssel.
///
/// Danach nur Befehlskopf, Längen und Statuswort. Die Entscheidung darüber liegt
/// nicht hier, sondern in `TagReader.send` der Lesebibliothek: an der einzigen
/// Stelle, durch die jedes APDU läuft. Eine Weiche im Datenpfad, kein Vorsatz.
///
/// ## Warum es einen Kopf hat
///
/// Wer ein Protokoll bekommt, muss wissen, wovon. Fassung, Bau, Gerät und
/// Systemfassung stehen deshalb oben — sonst ist die erste Rückfrage immer
/// dieselbe.
final class ReadLog {

    /// So viele Zeilen werden gehalten. Ein Lesevorgang mit allen Datengruppen
    /// kommt auf einige Hundert; mehr braucht niemand, und ein unbegrenzter
    /// Puffer in einer App, die Ausweise liest, ist eine schlechte Idee.
    private static let maximum = 400

    private var lines: [String] = []
    private var start: Date?
    private let lock = NSLock()

    static let shared = ReadLog()

    /// Hängt die Mitschrift der Lesebibliothek ein. Einmal beim Start.
    func install() {
        TagReader.trace = { [weak self] line in
            self?.add(line)
        }
    }

    func beginn(_ was: String) {
        lock.lock()
        lines = []
        start = Date()
        lock.unlock()
        add("— \(was) —")
    }

    func add(_ line: String) {
        lock.lock()
        let seit = start.map { String(format: "%6.2fs", Date().timeIntervalSince($0)) } ?? "      "
        lines.append("\(seit) \(line)")
        if lines.count > ReadLog.maximum {
            lines.removeFirst(lines.count - ReadLog.maximum)
        }
        lock.unlock()
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lines.isEmpty
    }

    var zeilen: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }

    /// Das Protokoll zum Verschicken, mit Kopf.
    func text(kopfzusatz: String = "") -> String {
        lock.lock()
        let body = lines.joined(separator: "\n")
        lock.unlock()

        var kopf = [
            "IDReader \(AppInfo.version) (\(AppInfo.build))",
            "\(DeviceInfo.model) · iOS \(DeviceInfo.system)",
        ]
        if !kopfzusatz.isEmpty { kopf.append(kopfzusatz) }
        kopf.append("Keine Personendaten: nach dem Aufbau der gesicherten")
        kopf.append("Verbindung stehen nur Laengen und Statuswoerter darin.")
        return kopf.joined(separator: "\n") + "\n\n" + body
    }
}

/// Gerät und Systemfassung, für den Kopf des Protokolls.
enum DeviceInfo {
    static var model: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let raw = withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(cString: bytes.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        return raw
    }

    static var system: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
}
