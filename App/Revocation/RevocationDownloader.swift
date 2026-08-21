import Foundation
import IDReaderCore

/// **Die einzige Stelle dieser App, die ins Netz greift.**
///
/// ## Was das umkehrt, und warum es trotzdem hier steht
///
/// Bis hierher stimmte ein Satz, der im Hinweis beim ersten Start, in drei
/// Store-Beschreibungen und in drei Datenschutzerklaerungen steht: die App hat
/// keinen Netzzugriff. Ab hier stimmt er nicht mehr, und deshalb sind alle diese
/// Texte mit derselben Aenderung angepasst worden. Eine Zusage, die an einer
/// Stelle bleibt und an einer anderen fallengelassen wird, ist schlimmer als
/// keine.
///
/// Was dafuer gewonnen ist: eine Sperrliste sagt, ob ein Dokumentsignierer
/// zurueckgezogen wurde. Ohne sie kann die Echtheitspruefung nur feststellen,
/// dass eine Signatur mathematisch aufgeht - nicht, ob ihr noch zu glauben ist.
/// Sechs der neun hinterlegten italienischen CSCA-Zertifikate nennen eine
/// Verteilstelle; die Frage ist also beantwortbar, und eine beantwortbare Frage
/// unbeantwortet zu lassen war der schwaechere Teil dieser App.
///
/// ## Wie klein der Zugriff gehalten ist
///
/// * **Nur GET auf eine oeffentliche Datei.** Es geht nichts hinaus als die
///   Anfrage selbst: kein Datum aus einem Dokument, keine Geraetekennung, keine
///   Angabe darueber, dass ueberhaupt gelesen wurde. Genau das unterscheidet CRL
///   von OCSP, wo jede Anfrage die Seriennummer des gerade geprueften
///   Zertifikats mitschickt.
/// * **Nie waehrend eines Lesevorgangs.** Der Zeitpunkt einer Anfrage waere sonst
///   selbst eine Mitteilung - „hier wurde eben ein Ausweis gelesen". Geholt wird
///   beim Starten und auf ausdrueckliche Anforderung.
/// * **Die Adresse steht in den Zertifikaten**, nicht in diesem Quelltext. Kein
///   Rechnername, den jemand hier ausgedacht hat.
/// * **Eine Sitzung ohne Gedaechtnis.** `.ephemeral`: keine Kekse, kein
///   Zwischenspeicher, keine Anmeldedaten auf der Platte.
/// * **Was hereinkommt, wird geprueft, bevor es gilt.** Die Signatur der Liste
///   gegen dieselben CSCA-Zertifikate - siehe ``RevocationListVerifier``. Eine
///   untergeschobene leere Liste wuerde jeden gesperrten Signierer wieder gueltig
///   aussehen lassen.
/// * **Abschaltbar.** ``AppSettings/revocationUpdatesEnabled``. Aus heisst: die
///   App ist wieder vollstaendig offline, und die Datensaetze sagen „nicht
///   geprueft" statt etwas zu behaupten.
struct RevocationDownloader: Sendable {

    /// Was ein Durchgang ergeben hat.
    enum Outcome: Sendable, Equatable {
        /// Eine neue Liste liegt vor.
        case updated(Date)
        /// Der Abruf ging durch, brachte aber nichts Neueres.
        case unchanged
        /// Kein Netz, oder die Stelle war nicht zu erreichen.
        case unreachable
        /// Etwas kam an und wurde abgewiesen - mit Grund.
        case rejected(String)
        /// Keines der hinterlegten Zertifikate nennt eine Verteilstelle.
        case noSource
    }

    let store: RevocationStore
    /// Nur der Diagnose - nie Inhalte.
    let log: (@Sendable (String) -> Void)?

    init(store: RevocationStore, log: (@Sendable (String) -> Void)? = nil) {
        self.store = store
        self.log = log
    }

    /// Die Verteilstellen aus den hinterlegten Zertifikaten, ohne Doppelungen.
    static func sources() -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for certificate in CscaTrustStore.load() {
            for text in CertificateReader.crlDistributionPoints(
                ofCertificate: [UInt8](certificate)
            ) {
                guard !seen.contains(text), let url = URL(string: text),
                      url.scheme?.lowercased() == "https"
                else { continue }
                seen.insert(text)
                result.append(url)
            }
        }
        return result
    }

    /// Holt die Listen und nimmt auf, was besteht.
    func refresh() async -> Outcome {
        let sources = Self.sources()
        guard !sources.isEmpty else { return .noSource }

        var outcome = Outcome.unreachable
        for url in sources {
            switch await fetch(url) {
            case .updated(let date):
                // Ein Erfolg gewinnt gegen alles, was danach kommt.
                outcome = .updated(date)
            case .unchanged:
                if case .updated = outcome {} else { outcome = .unchanged }
            case .rejected(let reason):
                if case .updated = outcome {} else if case .unchanged = outcome {} else {
                    outcome = .rejected(reason)
                }
            case .unreachable, .noSource:
                continue
            }
        }
        return outcome
    }

    private func fetch(_ url: URL) async -> Outcome {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                log?("Sperrliste: Antwort \(http.statusCode)")
                return .unreachable
            }
            // Eine Sperrliste ist Kilobytes gross. Alles jenseits davon wird nicht
            // erst geparst.
            guard data.count <= 8 * 1024 * 1024 else {
                return .rejected("zu gross")
            }
            let before = store.newestListIssuedAt
            if let rejection = store.accept(der: data) {
                if rejection == .olderThanStored { return .unchanged }
                log?("Sperrliste abgewiesen: \(rejection)")
                return .rejected("\(rejection)")
            }
            guard let issued = store.newestListIssuedAt else { return .unchanged }
            // Dieselbe Liste noch einmal ist kein Fortschritt. Der Unterschied
            // zaehlt: nur eine wirklich neuere Liste ist ein Grund, die
            // vorhandenen Datensaetze noch einmal abzugleichen.
            guard before == nil || issued > before! else { return .unchanged }
            return .updated(issued)
        } catch {
            log?("Sperrliste nicht erreichbar")
            return .unreachable
        }
    }
}
