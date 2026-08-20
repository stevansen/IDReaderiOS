import SwiftUI
import UIKit

/// Die Kamera des Systems.
///
/// ## Eine Zusage, die auf iOS nicht zu halten ist
///
/// Die Android-Fassung fotografiert ueber `ACTION_IMAGE_CAPTURE`, also ueber die
/// Kamera-App des Systems, und braucht dadurch **keine** Kameraberechtigung: die
/// fremde App bringt ihre eigene mit. Die App bleibt damit bei NFC als einziger
/// Berechtigung, und das steht so im Store-Eintrag.
///
/// Auf iOS gibt es diesen Weg nicht. `UIImagePickerController` mit
/// `sourceType == .camera` laeuft im eigenen Prozess und verlangt
/// `NSCameraUsageDescription`. Die App hat damit eine Berechtigung mehr als das
/// Original - das ist nicht zu umgehen und gehoert in den Store-Eintrag und in die
/// Datenschutzerklaerung, statt es zu verschweigen.
///
/// Was **bleibt**: das Bild geht nie in die Fotobibliothek und nie auf die Platte.
/// Es lebt als `UIImage` im Speicher, bis die Erkennung durch ist, und wird dann
/// fallen gelassen. Die Android-Fassung braucht dafuer eine Zieldatei im Cache und
/// muss sie hinterher loeschen; hier gibt es nichts zu loeschen.
struct CameraPicker: UIViewControllerRepresentable {

    /// Das aufgenommene Bild, oder nil bei Abbruch.
    let onResult: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        // Kein Zuschneiden: der Ausschnitt entscheidet mit darueber, was die
        // Erkennung findet, und ein aufgezwungenes Quadrat schneidet der CIE
        // regelmaessig die Zeile mit der CAN ab.
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let onResult: (UIImage?) -> Void
        /// Genau eine Antwort. Beide Rueckwege koennen feuern, wenn der Benutzer
        /// schnell ist, und ein zweiter Aufruf traefe eine Auswertung, die schon
        /// laeuft.
        private var answered = false

        init(onResult: @escaping (UIImage?) -> Void) {
            self.onResult = onResult
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            answer(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            answer(nil)
        }

        private func answer(_ image: UIImage?) {
            guard !answered else { return }
            answered = true
            onResult(image)
        }
    }
}
