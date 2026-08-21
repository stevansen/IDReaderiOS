import Foundation

/// Archiv der gelesenen Ausweise, 30 Tage lang.
///
/// Gedacht fuer den Einsatz: mehrere Personen hintereinander lesen und die
/// Angaben spaeter beim Schreiben des Berichts wieder zur Hand haben.
///
/// Verschluesselt mit einem Schluessel aus dem Schluesselbund, der das Geraet nicht
/// verlaesst - siehe ``KeychainArchiveKeyStore``. Wer die Datei kopiert, hat
/// verschluesselten Datenmuell.
///
/// Der Verfall wird beim Lesen geprueft, nicht per Hintergrundaufgabe: zu alte
/// Eintraege werden beim ersten Zugriff entfernt und sofort weggeschrieben. Damit
/// gibt es keinen Fall, in dem alte Daten noch auftauchen, weil eine
/// Aufraeumaufgabe nicht lief.
///
/// Das ganze Archiv liegt in einer Datei und wird bei jeder Aenderung
/// vollstaendig neu geschrieben. Bei der zu erwartenden Groessenordnung - Dutzende
/// Eintraege, nicht Zehntausende - ist das einfacher und weniger fehleranfaellig
/// als eine Datenbank.
public final class DocumentArchive: @unchecked Sendable {

    /// Aufbewahrungsdauer laut Vorgabe.
    public static let retentionDays = 30

    private let file: URL
    private let crypto: ArchiveCrypto
    private let lock = NSLock()

    /// Diagnose fuer den Aufrufer - nie Inhalte, nur Fehlerarten.
    public var log: ((String) -> Void)?

    public init(file: URL, keys: ArchiveKeyStore) {
        self.file = file
        self.crypto = ArchiveCrypto(keys: keys)
    }

    /// Der ueblich gelegene Ort: `Library/Application Support/archive.bin`.
    ///
    /// Nicht in `Documents`: das ist auf iOS der Ordner, den der Benutzer in der
    /// Dateien-App sieht, und ein Archiv mit Ausweisdaten hat dort nichts
    /// verloren - auch nicht verschluesselt.
    public static func defaultFile() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("archive.bin")
    }

    /// Alle nicht abgelaufenen Eintraege, neueste zuerst.
    ///
    /// Sind abgelaufene dabei, wird die Datei gleich ohne sie neu geschrieben.
    public func load() -> [StoredDocument] {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    private func loadLocked() -> [StoredDocument] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }

        // Zwei Fehlerarten, zwei Antworten. Ein Fehler beim *Lesen* der Datei ist
        // voruebergehend - volle Platte, unterbrochener Zugriff - und darf nichts
        // loeschen: beim naechsten Versuch ist die Datei vielleicht wieder da.
        // Erst ein Fehler beim *Entschluesseln oder Zerlegen* heisst, dass der
        // Inhalt selbst nicht mehr zu retten ist (Schluesselverlust, zerrissener
        // Schreibvorgang) - dann, und nur dann, wird aufgeraeumt, denn
        // verschluesselter Datenmuell wird nie wieder lesbar.
        //
        // Frueher galt beides als dasselbe, und ein einziger voruebergehender
        // Lesefehler loeschte das ganze Archiv.
        let bytes: Data
        do {
            bytes = try Data(contentsOf: file)
        } catch {
            note("Lesen fehlgeschlagen", error)
            return []
        }

        let all: [StoredDocument]
        do {
            all = StoredDocumentCodec.decodeAll(try crypto.decrypt(bytes), log: log)
        } catch {
            note("Entschluesseln fehlgeschlagen", error)
            clearLocked()
            return []
        }

        // Aufraeumen beim Lesen, nicht nur beim Schreiben: die Regel "ein Eintrag
        // pro Person" gilt fuer das ganze Archiv. Dubletten, die eine fruehere
        // Fassung der App angelegt hat, verschwinden so von selbst.
        let current = dedupe(all.filter { !isExpired($0.storedAt) })
        if current.count != all.count {
            _ = writeLocked(current)
        }

        return current.sorted { $0.storedAt > $1.storedAt }
    }

    /// Nimmt einen Lesevorgang auf und gibt das neue Archiv zurueck.
    ///
    /// Pro Person bleibt genau ein Eintrag. Liegt zu ihr schon einer vor, werden
    /// beide zusammengefuehrt statt ein zweiter angelegt - siehe ``merge``.
    public func add(_ document: StoredDocument) -> [StoredDocument] {
        lock.lock()
        defer { lock.unlock() }

        let document = minimised(document)
        let current = loadLocked()
        // Erst sortieren, dann begrenzen - sonst faellt beim Anschlagen der
        // Notbremse ein beliebiger Eintrag weg statt des aeltesten.
        let updated = Array(
            dedupe(current + [document])
                .sorted { $0.storedAt > $1.storedAt }
                .prefix(DocumentArchive.maxRecordsGuard)
        )
        // Scheitert das Speichern, kommt der alte Stand zurueck: die Liste auf dem
        // Schirm soll zeigen, was wirklich aufbewahrt ist, nicht was aufbewahrt
        // sein sollte.
        return writeLocked(updated) ? updated : current
    }

    /// Bereitet einen Datensatz fuer die Ablage vor.
    ///
    /// Zwei Schritte, und der zweite haengt am ersten: die Felder, die kein
    /// Anwendungsfall braucht, fallen weg, und weil dabei der Codice Fiscale
    /// verschwindet, tritt an seine Stelle sein Abdruck. Ohne den waere die Regel
    /// „ein Eintrag pro Person" nicht mehr zu halten.
    ///
    /// Scheitert der Abdruck - der Schluesselbund ist nur bei entsperrtem Geraet
    /// zu haben -, bleibt das Feld leer und die Ablage faellt auf die
    /// Dokumentnummer zurueck. Ein Eintrag, der einmal nicht mit einem aelteren
    /// zusammengefuehrt wird, ist ein sichtbarer Schoenheitsfehler; ein
    /// abgebrochenes Speichern waere ein verlorener Lesevorgang.
    private func minimised(_ document: StoredDocument) -> StoredDocument {
        var copy = document
        if copy.identityDigest == nil,
           let cf = document.data.codiceFiscale?.trimmingCharacters(in: .whitespaces),
           !cf.isEmpty {
            copy.identityDigest = try? crypto.identityDigest(for: cf)
        }
        copy.data = document.data.minimisedForStorage()
        return copy
    }

    /// Entfernt die genannten Eintraege und gibt das neue Archiv zurueck.
    public func remove(ids: Set<String>) -> [StoredDocument] {
        lock.lock()
        defer { lock.unlock() }

        let current = loadLocked()
        let updated = current.filter { !ids.contains($0.id) }
        return writeLocked(updated) ? updated : current
    }

    /// Loescht das ganze Archiv.
    public func clear() {
        lock.lock()
        clearLocked()
        lock.unlock()
    }

    /// Verbleibende Aufbewahrungstage eines Eintrags, aufgerundet.
    public func remainingDays(storedAt: Int64) -> Int {
        let remaining = DocumentArchive.retentionMs - (currentTimeMillis() - storedAt)
        if remaining <= 0 { return 0 }
        return Int((remaining + DocumentArchive.dayMs - 1) / DocumentArchive.dayMs)
    }

    // -----------------------------------------------------------------------
    // Zusammenfuehren
    // -----------------------------------------------------------------------

    /// Fuehrt alle Eintraege derselben Person zusammen.
    ///
    /// Aufsteigend nach Zeitpunkt, damit ``merge`` den jeweils neueren Scan als
    /// den hinzukommenden sieht.
    private func dedupe(_ records: [StoredDocument]) -> [StoredDocument] {
        guard records.count >= 2 else { return records }

        var order: [String] = []
        var byIdentity: [String: StoredDocument] = [:]
        for record in records.sorted(by: { $0.storedAt < $1.storedAt }) {
            let key = record.identityKey
            if let previous = byIdentity[key] {
                byIdentity[key] = merge(previous, record)
            } else {
                byIdentity[key] = record
                order.append(key)
            }
        }
        return order.compactMap { byIdentity[$0] }
    }

    /// Fuehrt einen neuen Lesevorgang mit dem vorhandenen Eintrag derselben
    /// Person zusammen.
    ///
    /// Dieselbe Karte (gleiche Dokumentennummer): die neuen Angaben gewinnen, das
    /// Lichtbild bleibt aber erhalten, wenn eine der beiden Lesungen eines hat. So
    /// ergaenzt ein Lesen mit Bild nach einem schnellen Lesen das Bild, und ein
    /// spaeteres schnelles Lesen wirft es nicht wieder weg.
    ///
    /// Verschiedene Karten (Ausweis wurde neu ausgestellt): es gewinnt das
    /// Dokument mit dem spaeteren Ablaufdatum, samt dessen Lichtbild - ein Bild
    /// gehoert zu genau einer Karte.
    ///
    /// Der Zeitpunkt ist in jedem Fall der des letzten Auflegens: die Liste soll
    /// zeigen, wann diese Person zuletzt kontrolliert wurde.
    private func merge(_ previous: StoredDocument, _ incoming: StoredDocument) -> StoredDocument {
        let sameCard = previous.data.documentNumber
            .caseInsensitiveCompare(incoming.data.documentNumber) == .orderedSame

        var winner: StoredDocument
        if sameCard || incoming.expiryKey > previous.expiryKey {
            winner = incoming
        } else {
            winner = previous
        }

        let photo = sameCard
            ? (incoming.data.photo ?? previous.data.photo)
            : winner.data.photo

        winner.data.photo = photo
        winner.storedAt = max(previous.storedAt, incoming.storedAt)
        return winner
    }

    // -----------------------------------------------------------------------
    // Datei
    // -----------------------------------------------------------------------

    private func writeLocked(_ documents: [StoredDocument]) -> Bool {
        if documents.isEmpty {
            clearLocked()
            return true
        }

        do {
            // Erst daneben schreiben, dann umbenennen: der Austausch ist im selben
            // Verzeichnis atomar, die Datei ist also zu jedem Zeitpunkt entweder
            // der alte oder der neue Stand. Direkt hineinzuschreiben hinterliess
            // bei einem Prozessende mitten im Schreiben einen Torso, dessen
            // GCM-Pruefung beim naechsten Laden scheitert - und der sah aus wie ein
            // Schluesselverlust.
            let payload = try crypto.encrypt(try StoredDocumentCodec.encodeAll(documents))
            let temporary = file.deletingLastPathComponent()
                .appendingPathComponent(file.lastPathComponent + ".tmp")

            try? FileManager.default.removeItem(at: temporary)
            #if os(iOS)
            // Klasse A: die Datei ist nur bei entsperrtem Geraet zu lesen, wie der
            // Schluessel, mit dem sie verschluesselt ist. Auf dem Mac (Tests) gibt
            // es diese Option nicht.
            try payload.write(to: temporary, options: [.atomic, .completeFileProtection])
            #else
            try payload.write(to: temporary, options: [.atomic])
            #endif
            try protect(temporary)

            if FileManager.default.fileExists(atPath: file.path) {
                _ = try FileManager.default.replaceItemAt(file, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: file)
            }
            try protect(file)
            return true
        } catch {
            // Ein stillschweigend fehlgeschlagenes Speichern ist schlimmer als
            // keines: die App verspricht dann eine Aufbewahrung, die es nicht gibt.
            note("Speichern fehlgeschlagen", error)
            return false
        }
    }

    /// Aus der Sicherung heraushalten.
    ///
    /// Das Gegenstueck zu `allowBackup="false"` und den `dataExtractionRules` der
    /// Android-Fassung. Ohne diese Kennzeichnung landet die verschluesselte Datei
    /// in der iCloud- und der Rechnersicherung - und mit ihr auf einem Geraet, auf
    /// dem der Schluessel aus dem Schluesselbund gar nicht mehr liegt. Der Nutzen
    /// waere null, die Zusage in der Datenschutzerklaerung waere gebrochen.
    private func protect(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }

    private func clearLocked() {
        try? FileManager.default.removeItem(at: file)
    }

    private func isExpired(_ storedAt: Int64) -> Bool {
        let elapsed = currentTimeMillis() - storedAt
        // Eine zurueckgestellte Uhr darf nicht dazu fuehren, dass etwas ewig
        // liegen bleibt; ein negatives Alter gilt als abgelaufen.
        return elapsed < 0 || elapsed > DocumentArchive.retentionMs
    }

    /// Nur die Fehlerart, kein Inhalt - hier laufen Personendaten durch.
    private func note(_ what: String, _ error: Error) {
        log?("\(what): \(type(of: error)): \(error)")
    }

    /// Notbremse gegen unbegrenztes Wachstum. Bei 30 Tagen Aufbewahrung und
    /// Einsatzgebrauch nicht zu erwarten, aber eine Datei, die bei jeder Aenderung
    /// komplett neu geschrieben wird, soll nicht beliebig gross werden.
    private static let maxRecordsGuard = 500

    private static let dayMs: Int64 = 24 * 60 * 60 * 1000
    private static let retentionMs = Int64(retentionDays) * dayMs
}
