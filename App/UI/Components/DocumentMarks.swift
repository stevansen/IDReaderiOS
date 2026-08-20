import SwiftUI
import IDReaderCore

/// Die beiden Zeichen, an denen ein Datensatz in einer Liste zu erkennen ist.
///
/// Beide stehen im Archiv und im Teilen-Schirm, und beide muessen dort dasselbe
/// bedeuten. Sie liegen deshalb in einer Datei und nicht zweimal nebeneinander:
/// ein Siegel, das an einer Stelle anders gesetzt wuerde als an der anderen, waere
/// schlimmer als gar keines.

/// Die Dokumentart als getoente Kachel.
///
/// Traegt die Farbe ihrer Art - Ausweis blau, Pass braun, Fahrerlaubnis rosé -
/// und sagt damit auf einen Blick nicht nur, welche Art es ist, sondern auch, ob
/// die Angaben aus einem Chip oder aus einem Foto stammen.
struct DocumentTile: View {
    let mode: DocumentMode

    @Environment(\.palette) private var palette

    var body: some View {
        let tint = DocumentPalette.tint(mode, dark: palette.isDark)
        Image(systemName: symbol)
            .font(.system(size: 20))
            .foregroundStyle(tint.content)
            .frame(width: 34, height: 42)
            .background(tint.container, in: .rect(cornerRadius: 4))
    }

    private var symbol: String {
        switch mode {
        // Wie die Karte: quer, mit Lichtbild links.
        case .identityCard, .drivingLicence: "person.text.rectangle"
        case .passport: "book.closed"
        }
    }
}

/// Das Urteil ueber die Echtheit.
///
/// Drei Faelle, und sie duerfen einander nicht aehneln:
///
/// - Aus dem Chip gelesen und geprueft: das gruene Siegel.
/// - Aus einem Foto gelesen: gar kein Siegel, sondern der Vorbehalt in Worten.
///   Ein durchgestrichenes oder graues Siegel stand hier frueher und war falsch -
///   es liest sich als „Pruefung nicht bestanden", waehrend es nie eine Pruefung
///   gab. Der Unterschied ist der Grund, warum es diese Zeichen ueberhaupt gibt:
///   was aus einem Foto stammt, traegt kein Zeugnis.
/// - Aus dem Chip gelesen und dabei durchgefallen oder nicht pruefbar: das
///   durchgestrichene Siegel. Hier ist es richtig, denn hier gab es etwas zu
///   pruefen.
struct AuthenticityMark: View {
    let status: AuthenticityStatus
    let strings: Strings

    @Environment(\.palette) private var palette

    var body: some View {
        switch status {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(palette.verified)
                .accessibilityLabel(strings[.authenticityVerified])

        case .unverifiable:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                Text(strings[.authenticityUnverifiedShort])
                    .font(AppType.microLabel)
                    .lineLimit(1)
            }
            .foregroundStyle(palette.error)

        case .failed, .notChecked:
            Image(systemName: "xmark.seal.fill")
                .foregroundStyle(palette.error)
                .accessibilityLabel(strings[.authenticityFailed])
        }
    }
}

/// Die Dokumentgrafik.
///
/// Ihre ganze Aufgabe ist, zu verorten, wo der gesuchte Schluessel steht: bei der
/// Karte die sechs Ziffern unten rechts, beim Pass die zwei Zeilen unten auf der
/// Datenseite. Deshalb ist sie kein Schmuckbild, sondern eine Zeichnung mit
/// hervorgehobener Stelle - und deshalb darf sie weichen, sobald sie so flach
/// wird, dass die Stelle nicht mehr zu erkennen ist. Wo die Ziffern stehen, sagt
/// die Unterzeile der Ueberschrift dann in Worten.
struct DocumentGraphic: View {
    let mode: DocumentMode
    /// Die hervorgehobene Beispielangabe - eine erfundene CAN.
    var exampleCan = "482913"
    /// Welche Stelle gerade aufleuchtet, oder nil.
    var highlightDigit: Int?

    @Environment(\.palette) private var palette

    /// ID-1 nach ISO/IEC 7810: 85,60 × 53,98 mm.
    static let id1AspectRatio: CGFloat = 85.60 / 53.98
    /// Die Datenseite eines Passes im TD3-Format ist hochkant.
    static let td3AspectRatio: CGFloat = 125.0 / 88.0

    var body: some View {
        let ratio = mode == .passport ? DocumentGraphic.td3AspectRatio
                                      : DocumentGraphic.id1AspectRatio
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [palette.cardFaceStart, palette.cardFaceEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.outlineVariant, lineWidth: 1)
                }

            GeometryReader { geometry in
                let unit = geometry.size.height / 10
                ZStack(alignment: .topLeading) {
                    // Das Lichtbild links - bei allen drei Arten an derselben
                    // Stelle.
                    RoundedRectangle(cornerRadius: unit * 0.3)
                        .fill(palette.cardChip.opacity(0.35))
                        .frame(width: unit * 2.2, height: unit * 3)
                        .offset(x: unit * 0.8, y: unit * 2.2)

                    // Angedeutete Textzeilen rechts daneben.
                    VStack(alignment: .leading, spacing: unit * 0.45) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(palette.onSurfaceVariant.opacity(0.28))
                                .frame(width: unit * CGFloat(4.4 - Double(index) * 0.8),
                                       height: unit * 0.35)
                        }
                    }
                    .offset(x: unit * 3.6, y: unit * 2.4)

                    if mode == .identityCard {
                        canBox(unit: unit, width: geometry.size.width)
                    } else if mode == .passport {
                        mrzLines(unit: unit, width: geometry.size.width)
                    }
                }
            }
        }
        .aspectRatio(ratio, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Die sechs Ziffern unten rechts, gerahmt - die Stelle, um die es geht.
    private func canBox(unit: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: unit * 0.12) {
            ForEach(Array(exampleCan.enumerated()), id: \.offset) { index, digit in
                Text(String(digit))
                    .font(.system(size: unit * 0.95, design: .monospaced))
                    .foregroundStyle(
                        index == highlightDigit ? palette.primary : palette.onSurfaceVariant
                    )
                    .fontWeight(index == highlightDigit ? .bold : .regular)
            }
        }
        .padding(unit * 0.25)
        .overlay {
            RoundedRectangle(cornerRadius: unit * 0.2)
                .stroke(palette.primary, lineWidth: 1.5)
        }
        .frame(maxWidth: width, alignment: .trailing)
        .offset(x: -unit * 0.7, y: unit * 7.4)
    }

    /// Die zwei Zeilen unten - beim Pass ist das der Schluessel.
    private func mrzLines(unit: CGFloat, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: unit * 0.3) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(palette.primary.opacity(0.75))
                    .frame(height: unit * 0.4)
            }
        }
        .padding(unit * 0.25)
        .frame(width: width - unit * 1.4)
        .overlay {
            RoundedRectangle(cornerRadius: unit * 0.2)
                .stroke(palette.primary, lineWidth: 1.5)
        }
        .offset(x: unit * 0.7, y: unit * 8)
    }
}
