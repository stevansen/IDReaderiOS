import SwiftUI
import IDReaderCore

/// Eine Schrittkarte: nummerierte Marke, Ueberschrift, Inhalt.
///
/// Der Aufbau, der die drei Masken zu einer Familie macht. Die Nummer ist keine
/// Zierde - sie sagt, dass es eine Reihenfolge gibt und an welcher Stelle man
/// steht.
struct StepCard<Content: View, Trailing: View>: View {

    let number: Int
    let title: String
    var subtitle: String?
    var subtitleColor: Color?
    /// Ob dieser Schritt an der Reihe ist.
    ///
    /// Ist er es nicht, bleibt die Marke ein leerer Ring. Die Karte selbst wird
    /// nicht abgeschwaecht: der Knopf darin sagt schon, dass er gesperrt ist, und
    /// ein blasser Rahmen darum waere nur schlechter zu lesen.
    var badgeActive = true
    /// Ob die Unterzeile unter der Titelzeile steht statt neben der Beigabe.
    ///
    /// Neben einer Beigabe rechts bleiben der Unterzeile gut zweihundert Punkte,
    /// und daraus werden schnell drei Zeilen. Unter der Zeile hat sie die ganze
    /// Breite.
    var wideSubtitle = false
    var contentSpacing: CGFloat = 12
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Titelzeile und Unterzeile gehoeren zusammen und stehen deshalb in
            // einer eigenen Spalte: der Zwischenraum der aeusseren Spalte gilt
            // zwischen Kopf und Inhalt, nicht innerhalb des Kopfes.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: StepCard.badgeGap) {
                    StepBadge(number: number, active: badgeActive)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(AppType.cardHeading)
                        if let subtitle, !wideSubtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(subtitleColor ?? palette.onSurfaceVariant)
                        }
                    }
                    Spacer(minLength: 0)
                    trailing()
                }
                if let subtitle, wideSubtitle {
                    // Eingerueckt bis unter den Titel: die Unterzeile gehoert zur
                    // Ueberschrift und nicht zur Marke.
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(subtitleColor ?? palette.onSurfaceVariant)
                        .padding(.leading, StepCard.badgeSize + StepCard.badgeGap)
                        .padding(.top, 2)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(palette.outlineVariant, lineWidth: 1)
        }
        .foregroundStyle(palette.onSurface)
    }

    static var badgeSize: CGFloat { 24 }
    static var badgeGap: CGFloat { 10 }
}

extension StepCard where Trailing == EmptyView {
    init(
        number: Int,
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color? = nil,
        badgeActive: Bool = true,
        wideSubtitle: Bool = false,
        contentSpacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            number: number,
            title: title,
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            badgeActive: badgeActive,
            wideSubtitle: wideSubtitle,
            contentSpacing: contentSpacing,
            trailing: { EmptyView() },
            content: content
        )
    }
}

/// Die nummerierte Marke.
///
/// Die Flaeche waechst mit der Schrift mit: bei 200 Prozent Systemschrift wuerde
/// eine feste Scheibe die Ziffer abschneiden.
struct StepBadge: View {
    let number: Int
    let active: Bool

    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 24

    var body: some View {
        Text("\(number)")
            .font(AppType.stepBadge)
            .foregroundStyle(active ? palette.onPrimary : palette.onSurfaceVariant)
            .frame(width: size, height: size)
            .background(active ? palette.primary : .clear, in: .circle)
            .overlay {
                if !active {
                    Circle().stroke(palette.outline, lineWidth: 1.5)
                }
            }
    }
}

/// „von Hand" zwischen zwei Linien - die Grenze zur Handeingabe.
///
/// Rechts daneben der Weg zurueck: `onUsePhoto` schliesst die Handeingabe und
/// stellt die Maske wieder auf den Fotoweg. Vorher gab es diesen Weg nicht - wer
/// die Handeingabe aufgeklappt hatte, kam aus ihr nur wieder heraus, indem er sie
/// zu Ende brachte. Der Knopf, der sie geoeffnet hat, liegt dann naemlich unter
/// dem Ziffernblock und ist selbst nicht mehr zu sehen.
///
/// Ein Zeichen mit einem Wort und nicht nur ein Zeichen: die Kamera allein
/// koennte auch heissen, dass jetzt sofort fotografiert wird. Der Knopf tut
/// weniger - er legt die Maske zurueck, und der grosse Knopf darauf macht das
/// Bild.
struct ManualDivider: View {
    let label: String
    let backLabel: String
    var onUsePhoto: (() -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            rule
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(palette.onSurfaceVariant)
            rule
            if let onUsePhoto {
                Button(action: onUsePhoto) {
                    Label(backLabel, systemImage: "camera")
                        .font(AppType.actionSmall)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(palette.primary)
            }
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.outlineVariant)
            .frame(height: 1)
    }
}

/// Eine Ableszeile: Beschriftung links, Wert rechts.
///
/// Der Wert steht nichtproportional, weil er abgeschrieben ist und nicht
/// formuliert - und weil sich Ziffern dann untereinander ausrichten. Fehlt er,
/// stehen Striche in gedaempfter Farbe.
struct KeyValueRow: View {
    let label: String
    let value: String?
    let placeholder: String
    var valueFont: Font = AppType.monoRowValue

    @Environment(\.palette) private var palette

    private var missing: Bool {
        (value ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
            Spacer(minLength: 0)
            Text(missing ? placeholder : value!)
                .font(valueFont)
                .foregroundStyle(missing ? palette.onSurfaceVariant : palette.onSurface)
        }
    }
}

/// Die untere Leiste: eine moegliche Warnung, darunter die Haupthandlung.
///
/// Ausserhalb des Scrollbereichs und mit eigener Flaeche, damit sie bei grosser
/// Schrift oder offener Tastatur nicht unter die Kante rutscht. Ausgerechnet zum
/// Abschliessen scrollen zu muessen waere die schlechteste Stelle dafuer.
struct BottomActionBar<Notice: View, Action: View>: View {
    @ViewBuilder var notice: () -> Notice
    @ViewBuilder var action: () -> Action

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            notice()
            action()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(palette.surface)
    }
}

extension BottomActionBar where Notice == EmptyView {
    init(@ViewBuilder action: @escaping () -> Action) {
        self.init(notice: { EmptyView() }, action: action)
    }
}
