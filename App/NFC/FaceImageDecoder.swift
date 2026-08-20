import Foundation
import ImageIO
import IDReaderCore
import UniformTypeIdentifiers

/// Decodiert das Lichtbild aus DG2.
///
/// DG2 der CIE haelt das Gesichtsbild als **JPEG 2000**, und iOS bringt dafuer -
/// wie Android - keinen oeffentlichen Decoder mit. Die Android-Fassung bindet
/// OpenJPEG als Bibliothek ein; hier ist diese Stelle noch offen (siehe
/// docs/ANDROID-TO-IOS.md).
///
/// Das Format wird an den **Magic Bytes** erkannt und nicht am MIME-Typ aus DG2:
/// das Feld ist auf manchen Karten falsch gesetzt, unter Android gemessen. Beide
/// Formen von JPEG 2000 werden unterschieden, der JP2-Container und der nackte
/// J2K-Codestream.
///
/// Laesst sich nicht decodieren, kommt trotzdem ein ``DocumentPhoto`` zurueck -
/// mit `jpegData == nil` und dem erkannten Format im MIME-Typ. Damit kann die
/// Oberflaeche sagen, woran es lag, statt stillschweigend nichts zu zeigen. Das
/// ist derselbe Umgang wie im Original und keine Notloesung: „hier war ein Bild,
/// das ich nicht lesen kann" ist eine Auskunft, „hier war nichts" waere eine
/// falsche.
enum FaceImageDecoder {

    static func decode(_ bytes: Data, declaredMimeType: String?) -> DocumentPhoto? {
        guard !bytes.isEmpty else { return nil }
        let detected = detectFormat(bytes) ?? declaredMimeType ?? "application/octet-stream"

        // Was ImageIO von sich aus lesen kann - auf iOS ist das JPEG und PNG,
        // JPEG 2000 nicht.
        if let source = CGImageSourceCreateWithData(bytes as CFData, nil),
           CGImageSourceGetCount(source) > 0,
           CGImageSourceCreateImageAtIndex(source, 0, nil) != nil {
            return DocumentPhoto(jpegData: bytes, mimeType: detected, sizeBytes: bytes.count)
        }

        return DocumentPhoto(jpegData: nil, mimeType: detected, sizeBytes: bytes.count)
    }

    /// Das Format an den ersten Bytes.
    static func detectFormat(_ bytes: Data) -> String? {
        let head = [UInt8](bytes.prefix(12))

        // JP2-Container: der JPEG-2000-Signaturkasten.
        if head.count >= 12,
           head[0] == 0x00, head[1] == 0x00, head[2] == 0x00, head[3] == 0x0C,
           head[4] == 0x6A, head[5] == 0x50, head[6] == 0x20, head[7] == 0x20 {
            return "image/jp2"
        }
        // Nackter J2K-Codestream: SOC-Marke, dann SIZ.
        if head.count >= 4, head[0] == 0xFF, head[1] == 0x4F, head[2] == 0xFF, head[3] == 0x51 {
            return "image/j2k"
        }
        if head.count >= 3, head[0] == 0xFF, head[1] == 0xD8, head[2] == 0xFF {
            return "image/jpeg"
        }
        if head.count >= 8, head[0] == 0x89, head[1] == 0x50, head[2] == 0x4E, head[3] == 0x47 {
            return "image/png"
        }
        return nil
    }
}
