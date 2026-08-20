import Foundation

extension DocumentExport {

    /// Dieselben Angaben als HTML, fuer den Mailversand.
    ///
    /// Nur fuer die lesbare Fassung. Die Lichtbilder werden als `data:`-URI
    /// eingebettet, soweit `photoDataURIs` welche liefert - geschluesselt nach der
    /// Position des Datensatzes in `documents`. Ob das Mailprogramm sie stehen
    /// laesst, entscheidet es selbst; der Anhang ist die Rueckfallebene, die immer
    /// ankommt.
    ///
    /// Die Gestaltung steckt in Attributen und nicht in einem Stylesheet:
    /// Mailprogramme entfernen `<style>`-Bloecke regelmaessig.
    public func buildHtml(
        _ documents: [StoredDocument],
        photoDataURIs: [Int: String] = [:]
    ) -> String {
        var out = "<div style=\"font-family:sans-serif;font-size:14px;color:#111\">"

        if documents.count > 1 {
            out += "<p><b>"
            out += escape(strings.plural(.exportCollectionHeader, documents.count))
            out += "</b><br>"
            out += escape(strings.format(.exportCreatedAt, htmlTimestamp(Date())))
            out += "</p>"
        }

        for (index, document) in documents.enumerated() {
            if index > 0 {
                out += "<hr style=\"border:0;border-top:1px solid #ccc\">"
            }
            let record = structure(document)

            out += "<h3 style=\"margin:12px 0 2px\">" + escape(record.title) + "</h3>"
            out += "<div style=\"color:#666;font-size:12px\">" + escape(record.subtitle) + "</div>"

            if let notice = record.notice {
                out += "<div style=\"margin:8px 0;padding:8px 10px;border-left:3px solid #B3261E;"
                out += "background:#FCEEEE;color:#8C1D18;font-size:12px\">"
                out += escape(notice)
                out += "</div>"
            }

            if let source = photoDataURIs[index] {
                out += "<div style=\"margin:10px 0\"><img src=\""
                out += source
                out += "\" width=\"120\" alt=\"\" style=\"border-radius:6px\"></div>"
            }

            for section in record.sections {
                out += "<div style=\"margin-top:10px;color:#0B4F8A;font-size:12px\"><b>"
                out += escape(section.title)
                out += "</b></div>"
                out += "<table cellpadding=\"2\" cellspacing=\"0\">"
                for row in section.rows {
                    out += "<tr><td style=\"color:#666;padding-right:14px\">"
                    out += escape(row.label)
                    out += "</td><td>"
                    out += escape(row.value)
                    out += "</td></tr>"
                }
                out += "</table>"
            }
        }

        out += "</div>"
        return out
    }

    /// Bewusst von Hand und nicht ueber eine Systemfunktion: die Ausweisdaten
    /// sollen nicht davon abhaengen, wie eine Bibliotheksfassung Sonderzeichen
    /// behandelt. Ein Apostroph in "CARTA D'IDENTITÀ" wuerde sonst je nach
    /// Fassung anders herauskommen.
    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func htmlTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date)
    }
}
