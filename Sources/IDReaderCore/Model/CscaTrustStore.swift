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
/// Diese Zertifikate tragen noch eine zweite Aufgabe: sechs von ihnen nennen eine
/// Verteilstelle fuer die Sperrliste, und dieselben neun pruefen deren Signatur -
/// siehe ``RevocationStore`` und ``RevocationListVerifier``. Frueher stand hier,
/// eine Sperrlistenabfrage sei bewusst nicht umgesetzt, weil sie Netzzugriff
/// braeuchte. Sie ist es jetzt, und der Netzzugriff dafuer ist die eine Ausnahme,
/// die die App macht - benannt in `App/Revocation/RevocationDownloader.swift`.
///
/// **OCSP** waere weiter nicht in Ordnung: dort geht die Seriennummer des gerade
/// geprueften Zertifikats mit hinaus, und damit ein Hinweis darauf, welches
/// Dokument jemand in der Hand hat. Eine CRL wird als Ganzes geholt und danach
/// offline abgeglichen.
///
/// Ein abgelaufener *Dokumentsignierer* gilt bewusst nicht als Fehlschlag -
/// Signierer laufen nach Monaten ab, waehrend die Karten, die sie signiert haben,
/// zehn Jahre gueltig bleiben.
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

    /// Dieselben Zertifikate als PEM-Buendel, auf der Platte.
    ///
    /// Braucht die Kettenpruefung: OpenSSL laedt einen Vertrauensspeicher ueber
    /// `X509_LOOKUP_file`, und der will **eine** Datei in PEM. Neun einzelne
    /// DER-Dateien nuetzen ihm nichts.
    ///
    /// Das Buendel liegt daneben und wird nicht aus den DER-Dateien erzeugt: es
    /// soll genau dieselben neun Zertifikate enthalten, und eine Umwandlung zur
    /// Laufzeit waere eine zweite Stelle, an der sich das auseinanderentwickeln
    /// kann. Das Skript, das beide schreibt, ist dasselbe - siehe oben.
    public static func bundleURL() -> URL? {
        Bundle.module.url(
            forResource: "it-csca-bundle",
            withExtension: "pem",
            subdirectory: "csca"
        )
    }
}
