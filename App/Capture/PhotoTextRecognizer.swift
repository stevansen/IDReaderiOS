import Foundation
import UIKit
import Vision

/// Erkennt Text in einer Aufnahme.
///
/// ## Warum Vision und nicht ML Kit
///
/// Die Android-Fassung liefert das Erkennungsmodell im APK mit - und entfernt
/// dafuer die `INTERNET`-Berechtigung wieder aus dem Manifest, weil die Zusage
/// „die App kann technisch nichts uebertragen" im Store-Eintrag steht und eine
/// von einer Bibliothek stillschweigend hinzugefuegte Berechtigung sie aufheben
/// wuerde.
///
/// Auf iOS ist das gegenstandslos: Vision ist Teil des Systems, das Modell liegt
/// auf dem Geraet, und die App bindet fuer die Erkennung ueberhaupt keine fremde
/// Bibliothek ein. Damit ist die Zusage einfacher zu halten als vorher - aber sie
/// braucht eine andere Absicherung, weil iOS keine Berechtigung kennt, die man
/// entfernen koennte. Siehe `Scripts/check-no-network.sh`.
///
/// ## Genauigkeitsstufe
///
/// `.accurate`, nicht `.fast`. Es geht um sechs Ziffern in OCR-B und um
/// Versalien auf einer bedruckten Karte; die schnelle Stufe verliest dort
/// regelmaessig, und ein Fehlversuch am Chip kostet mehr als eine halbe Sekunde
/// Rechenzeit.
///
/// ## Sprachen
///
/// `usesLanguageCorrection = false`. Das ist keine Kleinigkeit: eine
/// Sprachkorrektur macht aus `U1974B315M` ein Wort, das sie kennt, und aus
/// `BOLZANO-BOZEN` etwas Naheliegenderes. Was hier gelesen wird, ist kein Text,
/// sondern eine Zeichenfolge.
enum PhotoTextRecognizer {

    /// - Returns: der erkannte Text, oder nil wenn die Erkennung gescheitert ist.
    ///   Das ist etwas anderes als ein leeres Ergebnis, bei dem die Erkennung
    ///   gelaufen ist und nichts gefunden hat.
    static func recognise(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // Die drei Sprachen der Karte. Die MRZ und die CAN sind sprachfrei, der
        // Kleindruck ist es nicht - und was die Erkennung fuer ein Wort haelt,
        // haengt daran.
        request.recognitionLanguages = ["it-IT", "de-DE", "en-US"]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: image.imageOrientation.cgOrientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return nil }

        // Zeilenweise, in der Reihenfolge, in der Vision sie liefert. Die Parser
        // rechnen genau damit: sie verlassen sich nicht auf die Reihenfolge - die
        // ist auf einer fotografierten Karte ohnehin willkuerlich -, sondern auf
        // die Form der Werte.
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

private extension UIImage.Orientation {
    /// Vision rechnet in CGImagePropertyOrientation, UIKit in seiner eigenen
    /// Aufzaehlung. Wer die Umrechnung weglaesst, bekommt bei einer im Hochformat
    /// aufgenommenen Karte gedrehten Text - und dann findet kein Muster mehr
    /// etwas.
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
