import Foundation

/// Die hinterlegten italienischen CSCA-Zertifikate.
///
/// Neun Stueck - sieben selbstsignierte Wurzeln, zwei Verkettungszertifikate -,
/// gezogen aus der **CSCA-Masterliste des BSI**, einer CMS-Struktur mit 588
/// Zertifikaten aus vielen Staaten, gefiltert auf `C=IT`. Sie sind der Anker fuer
/// den dritten Schritt der Passive Authentication, und der ist der, auf den es
/// ankommt: ohne ihn koennte jemand eine Karte mit selbst erzeugtem
/// Schluesselpaar bespielen, und die ersten zwei Schritte waeren trotzdem gruen.
///
/// Auffrischen wie in der Android-Fassung, mit demselben Skript:
///
/// ```bash
/// curl -L -o GermanMasterList.zip "https://www.bsi.bund.de/SharedDocs/Downloads/DE/BSI/ElekAusweise/CSCA/GermanMasterList.zip?__blob=publicationFile"
/// python scripts/extract-csca.py DE_ML_*.ml IT Sources/IDReaderCore/Resources/csca
/// ```
///
/// Bewusst **nicht** umgesetzt: Sperrlistenabfrage (CRL/OCSP). Die braeuchte
/// Netzzugriff, und den hat diese App nicht. Ein abgelaufener *Dokumentsignierer*
/// gilt ebenfalls bewusst nicht als Fehlschlag - Signierer laufen nach Monaten
/// ab, waehrend die Karten, die sie signiert haben, zehn Jahre gueltig bleiben.
public enum CscaTrustStore {

    /// Die Zertifikate als DER-Bytes, in der Reihenfolge ihrer Dateinamen.
    ///
    /// Als Bytes und nicht als `SecCertificate`: wer sie prueft, ist das
    /// PACE-Backend, und das arbeitet mit OpenSSL. Eine Umwandlung hier waere
    /// eine, die dort wieder rueckgaengig gemacht wird.
    public static func load() -> [Data] {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "der",
            subdirectory: "csca"
        ) else {
            return []
        }
        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Data(contentsOf: $0) }
    }
}
