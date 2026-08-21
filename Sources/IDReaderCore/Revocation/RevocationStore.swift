import Foundation

/// Die Ablage fuer geladene Sperrlisten, und der Abgleich gegen sie.
///
/// ## Der Punkt der ganzen Uebung
///
/// Netz braucht das **Laden** der Liste. Der **Abgleich** braucht keins. Also
/// wird die Liste aufbewahrt, und danach ist jede Pruefung offline - auch die
/// zwanzigste an einem Tag ohne Empfang. Das ist der Unterschied zu OCSP, wo
/// jede einzelne Anfrage ins Netz geht und dem Betreiber dabei verraet, welches
/// Dokument gerade jemand in der Hand hat. Genau deshalb CRL und nicht OCSP.
///
/// ## Was hier liegt
///
/// Eine Datei pro Aussteller, benannt nach dem Abdruck seines Namens, im
/// Anwendungsordner. Unverschluesselt: eine CRL ist eine oeffentliche Urkunde
/// eines Staates, an ihr ist nichts zu verbergen. Von der Sicherung ist sie
/// ausgenommen, weil sie jederzeit wieder zu laden ist.
public final class RevocationStore: @unchecked Sendable {

    private let directory: URL
    private let trustedCertificates: [Data]
    private let log: (@Sendable (String) -> Void)?
    private let lock = NSLock()
    private var lists: [String: RevocationList] = [:]

    public init(
        directory: URL,
        trustedCertificates: [Data] = CscaTrustStore.load(),
        log: (@Sendable (String) -> Void)? = nil
    ) {
        self.directory = directory
        self.trustedCertificates = trustedCertificates
        self.log = log
        loadFromDisk()
    }

    /// Die vorhandene Ablage im Anwendungsordner.
    public static func standard(
        log: (@Sendable (String) -> Void)? = nil
    ) -> RevocationStore {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return RevocationStore(directory: base.appendingPathComponent("revocation"), log: log)
    }

    // MARK: - Bestand

    /// Die Liste eines Ausstellers, falls eine vorliegt.
    public func list(forIssuerDigest digest: String) -> RevocationList? {
        lock.lock()
        defer { lock.unlock() }
        return lists[digest]
    }

    /// Das Ausgabedatum der juengsten vorliegenden Liste.
    public var newestListIssuedAt: Date? {
        lock.lock()
        defer { lock.unlock() }
        return lists.values.map(\.thisUpdate).max()
    }

    /// Ob es sich lohnt, nach einer neueren Liste zu fragen.
    ///
    /// Wahr, wenn gar keine vorliegt oder eine vorhandene ihr eigenes
    /// Ablaufdatum ueberschritten hat. Eine noch gueltige Liste erneut zu holen
    /// waere eine Anfrage ohne Gegenwert - und jede Anfrage ist eine, die der
    /// Betreiber der Verteilstelle sieht.
    public func needsRefresh(at now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if lists.isEmpty { return true }
        return lists.values.contains { !$0.isCurrent(at: now) }
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lists.isEmpty
    }

    // MARK: - Aufnehmen

    public enum Rejection: Error, Equatable {
        case unreadable(String)
        case untrusted(RevocationListVerifier.Failure)
        case olderThanStored
    }

    /// Nimmt geladene Bytes auf - wenn sie eine Liste sind, und wenn sie stimmt.
    ///
    /// Gibt `nil`, wenn die Liste aufgenommen wurde, sonst den Grund.
    ///
    /// Geprueft wird die Signatur gegen die hinterlegten CSCA-Zertifikate. Eine
    /// Liste ohne gueltige Signatur wird verworfen: sie waere ein Weg, jeden
    /// gesperrten Signierer wieder gueltig aussehen zu lassen.
    ///
    /// Eine aeltere Liste ersetzt keine neuere. Sonst koennte ein Rueckspielen
    /// einer alten Ausgabe eine Sperre wieder verschwinden lassen.
    @discardableResult
    public func accept(der: Data) -> Rejection? {
        let list: RevocationList
        do {
            list = try RevocationList.parse([UInt8](der))
        } catch {
            log?("Sperrliste nicht lesbar: \(error)")
            return .unreadable("\(error)")
        }

        if let failure = RevocationListVerifier.verify(list, against: trustedCertificates) {
            log?("Sperrliste abgewiesen: \(failure)")
            return .untrusted(failure)
        }

        let digest = list.issuerDigest
        lock.lock()
        if let existing = lists[digest], existing.thisUpdate > list.thisUpdate {
            lock.unlock()
            return .olderThanStored
        }
        lists[digest] = list
        lock.unlock()

        write(der: der, forIssuerDigest: digest)
        log?("Sperrliste vom \(list.thisUpdate) aufgenommen, \(list.revokedSerials.count) Eintraege")
        return nil
    }

    // MARK: - Abgleich

    /// Gleicht einen Signierer gegen den vorhandenen Bestand ab.
    ///
    /// Gibt `nil`, wenn **ueberhaupt keine** Liste vorliegt - dann ist die
    /// Pruefung nicht ausgefallen, sondern noch nicht gelaufen, und der Datensatz
    /// bleibt offen, damit sie nachgeholt wird. Liegt eine Liste vor, nur nicht
    /// die dieses Ausstellers, ist das ein Ergebnis und keine offene Frage.
    public func evaluate(
        _ signer: SignerReference,
        now: Date = Date()
    ) -> RevocationCheck? {
        lock.lock()
        let matching = lists[signer.issuerDigest]
        let anyList = !lists.isEmpty
        lock.unlock()

        guard let matching else {
            guard anyList else { return nil }
            return RevocationCheck(
                outcome: .noListForIssuer,
                checkedAt: now,
                listIssuedAt: now,
                listExpiresAt: nil
            )
        }
        return RevocationCheck(
            outcome: matching.revokes(signer.serialHex) ? .revoked : .notRevoked,
            checkedAt: now,
            listIssuedAt: matching.thisUpdate,
            listExpiresAt: matching.nextUpdate
        )
    }

    // MARK: - Platte

    private func fileURL(forIssuerDigest digest: String) -> URL {
        directory.appendingPathComponent("\(digest).crl")
    }

    private func loadFromDisk() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.pathExtension == "crl" {
            guard let data = try? Data(contentsOf: url),
                  let list = try? RevocationList.parse([UInt8](data))
            else {
                // Unbrauchbares wird weggeraeumt statt bei jedem Start neu zu
                // scheitern. Verlust gibt es dabei nicht: die Liste ist oeffentlich.
                try? FileManager.default.removeItem(at: url)
                continue
            }
            lists[list.issuerDigest] = list
        }
    }

    private func write(der: Data, forIssuerDigest digest: String) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            var url = fileURL(forIssuerDigest: digest)
            try der.write(to: url, options: .atomic)
            var resource = URLResourceValues()
            resource.isExcludedFromBackup = true
            try? url.setResourceValues(resource)
        } catch {
            log?("Sperrliste nicht gespeichert: \(error)")
        }
    }
}
