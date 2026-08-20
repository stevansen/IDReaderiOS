import MessageUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import IDReaderCore

/// Die Wege, auf denen Daten die App verlassen koennen.
///
/// Bewusst nur Text und - beim Mailweg - ein Lichtbild als Anhang. Keine Datei
/// auf der Platte, nichts, was im Zwischenspeicher liegen bleibt.
///
/// Anders als unter Android braucht der Mailweg hier **keinen Dateianbieter**:
/// `MFMailComposeViewController` nimmt die Bytes unmittelbar an. Die Android-
/// Fassung musste die Bilder in den Cache schreiben, weil ein Anhang dort nur als
/// `content:`-URI zu uebergeben ist - und dann darauf achten, den Ordner vor jedem
/// Versand zu leeren. Dieser ganze Umgang entfaellt.
enum ExportActions {

    /// Legt den Text in die Zwischenablage.
    ///
    /// `expirationDate` ist der Ersatz fuer `EXTRA_IS_SENSITIVE` der Android-
    /// Fassung: iOS kennt keine Kennzeichnung „vertraulich", die die
    /// Systemvorschau ausblenden wuerde, aber es kann den Eintrag von sich aus
    /// verfallen lassen. Zwei Minuten reichen zum Einfuegen und sind kurz genug,
    /// dass Ausweisdaten nicht den Tag ueber in der Zwischenablage stehen.
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: text]],
            options: [.expirationDate: Date().addingTimeInterval(120)]
        )
    }

    /// Baut die Mail zusammen.
    ///
    /// Nur der lesbaren Fassung liegen Lichtbilder bei. Die JSON-Fassung geht ohne:
    /// sie ist zur maschinellen Uebernahme gedacht, und ein Bild waere dort nur
    /// Ballast, der zudem nicht in den Bericht gehoert.
    ///
    /// Die Dateinamen sind durchnummeriert und enthalten keinen Namen: der
    /// Dateiname eines Anhangs ist in jeder Mailuebersicht sichtbar, noch bevor
    /// jemand die Nachricht oeffnet.
    static func mailDraft(
        documents: [StoredDocument],
        to address: String,
        format: ExportFormat,
        strings: Strings
    ) -> MailDraft {
        let export = DocumentExport(strings: strings)

        var attachments: [MailDraft.Attachment] = []
        var dataURIs: [Int: String] = [:]

        if format == .readable {
            for (index, document) in documents.enumerated() {
                guard let jpeg = downscaled(document.data.photo?.jpegData) else { continue }
                attachments.append(
                    MailDraft.Attachment(
                        data: jpeg,
                        mimeType: "image/jpeg",
                        fileName: "lichtbild-\(index + 1).jpg"
                    )
                )
                // Zusaetzlich eingebettet: ob ein Mailprogramm ein `data:`-Bild im
                // HTML stehen laesst, entscheidet es selbst. Der Anhang ist die
                // Rueckfallebene, die immer ankommt.
                dataURIs[index] = "data:image/jpeg;base64," + jpeg.base64EncodedString()
            }
        }

        let body: String
        let isHTML: Bool
        if format == .readable {
            body = export.buildHtml(documents, photoDataURIs: dataURIs)
            isHTML = true
        } else {
            body = export.build(documents, format: .json)
            isHTML = false
        }

        return MailDraft(
            recipients: [address],
            // Der Betreff ist absichtlich neutral. Stuende dort der Name, tauchte er
            // in Betreffzeilen und Mitteilungen auf, noch bevor jemand die Nachricht
            // oeffnet.
            subject: strings[.shareSubject],
            body: body,
            isHTML: isHTML,
            attachments: attachments,
            /// Muss stimmen: die Zusage, dass kein Lichtbild dabei ist, darf nicht
            /// in einer Nachricht stehen, an der eines haengt.
            plainTextFallback: export.build(
                documents,
                format: format,
                photosAttached: !attachments.isEmpty
            )
        )
    }

    /// Verkleinert das Lichtbild vor dem Versand.
    ///
    /// Ein Lichtbild in Originalgroesse ist fuer eine Mail unnoetig, und ein
    /// eingebettetes Bild wird als Base64 um ein Drittel groesser.
    private static func downscaled(_ jpeg: Data?, maxEdge: CGFloat = 600) -> Data? {
        guard let jpeg, let image = UIImage(data: jpeg) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image.jpegData(compressionQuality: 0.85) }

        let factor = maxEdge / longest
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.85)
    }
}

/// Eine Mail, wie der Versender sie erwartet.
struct MailDraft: Identifiable {
    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    let id = UUID()
    let recipients: [String]
    let subject: String
    let body: String
    let isHTML: Bool
    let attachments: [Attachment]
    let plainTextFallback: String
}

/// Der Mailversand des Systems.
struct MailComposer: UIViewControllerRepresentable {
    let draft: MailDraft
    let onFinish: () -> Void

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> UIViewController {
        guard MailComposer.canSendMail else {
            // Kein eingerichtetes Mailkonto. Ein leerer Bildschirm waere hier das
            // Schlechteste; die Meldung dafuer steht schon im Katalog.
            return UIViewController()
        }
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(draft.recipients)
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: draft.isHTML)
        for attachment in draft.attachments {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )
        }
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    /// `@unchecked Sendable`: UIKit ruft die Zusage unten ausschliesslich auf dem
    /// Hauptfaden auf, sagt das im Protokoll aber nicht. Ohne die Kennzeichnung
    /// laesst sich `self` nicht in den Hauptfaden hinein geben, und die einzige
    /// Alternative waere, die Klasse an den Hauptfaden zu binden - womit sie das
    /// Protokoll nicht mehr erfuellt.
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate, @unchecked Sendable {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        /// UIKit ruft diese Zusage ausschliesslich auf dem Hauptfaden auf, sagt
        /// das aber im Protokoll nicht. `assumeIsolated` schreibt genau das hin -
        /// statt die Klasse an den Hauptfaden zu binden, was das Protokoll nicht
        /// mehr erfuellen wuerde, oder die Pruefung mit `@unchecked` abzuschalten.
        nonisolated func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
                onFinish()
            }
        }
    }
}

/// Der Teilen-Dialog des Systems, fuer „Andere App".
struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
