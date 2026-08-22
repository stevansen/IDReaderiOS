import SwiftUI
import IDReaderCore

/// Der gemeinsame Rahmen der drei Eingabemasken.
///
/// Vorher waren es drei getrennt gebaute Bildschirme, die einander zufaellig
/// aehnelten - mit drei eigenen Kopfbereichen und drei Archivzeilen an drei
/// verschiedenen Hoehen. Was daran auffiel, ist bezahlt: eine Aenderung an der
/// Grundform musste dreimal gemacht werden, und ein Fehler in ihr war dreimal
/// derselbe Fehler.
///
/// Hier steht sie einmal. Die Masken liefern nur noch ihren Inhalt.
///
/// ## Der Wechsel wandert
///
/// Beim Umschalten der Dokumentart bleibt der Kopfbereich stehen und nur der Teil
/// darunter zieht von der Seite herein - in der Richtung, in der umgeschaltet
/// wurde. Das ist nicht Zierde: der Umschalter liegt unter dem Finger, der ihn
/// gerade getroffen hat, und wuerde er mitwandern, waere die Bewegung genau dort,
/// wo man hinsieht, ohne dass sie etwas erklaert.
struct DocumentInputScaffold<Content: View>: View {

    let mode: DocumentMode
    let onModeChange: (DocumentMode) -> Void
    let archiveCount: Int
    let onOpenArchive: () -> Void
    let onOpenSettings: () -> Void
    let strings: Strings
    @ViewBuilder var content: (DocumentMode, Int) -> Content

    /// Wer die schon gewaehlte Art noch einmal antippt, will die Maske von vorn.
    /// Der Umschalter meldet das nicht nach oben - dort wechselt ja nichts -,
    /// sondern zaehlt hier hoch. Die Masken haengen ihren aufgeklappten Zustand an
    /// diesen Zaehler und fangen mit ihm neu an.
    @State private var resetCount = 0
    @Environment(\.palette) private var palette
    /// Nur fuer eine Entscheidung gebraucht: waagerecht oder untereinander.
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
                .id(mode)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
        }
        .animation(.easeInOut(duration: 0.22), value: mode)
    }

    /// Die Maske - und bei den Bedienungshilfen-Schriftgroessen in einem
    /// Rollbereich.
    ///
    /// ## Warum nicht immer
    ///
    /// Die Masken sind darauf gebaut, **ohne Rollen** auszukommen: beide Schritte
    /// gleichzeitig sichtbar, der Ziffernblock unten festgesetzt. Das ist die
    /// Entscheidung der Android-Fassung und sie ist richtig - wer ein Dokument in
    /// der Hand haelt, hat keine Hand zum Wischen.
    ///
    /// Sie hoert bei grosser Systemschrift auf zu funktionieren, und zwar nicht
    /// harmlos. Am Simulator mit der groessten Bedienungshilfen-Schrift stand da
    /// „No NFC av… / This device h…": SwiftUI hat keinen Platz, also kuerzt es,
    /// und gekuerzt wurde die **Fehlermeldung**, die erklaert, warum die App
    /// gerade nichts tun kann. Ein Rollbereich ist unbequem; eine unlesbare
    /// Begruendung ist schlimmer.
    ///
    /// Bei normaler Schrift bleibt alles, wie es war - kein Rollbereich, damit
    /// `Spacer` und der festgesetzte Ziffernblock weiter tun, was sie sollen.
    @ViewBuilder private var stage: some View {
        if typeSize.isAccessibilitySize {
            ScrollView {
                content(mode, resetCount)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            content(mode, resetCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @State private var previous: DocumentMode = .identityCard

    /// Richtung aus der Reihenfolge im Umschalter: nach rechts umgeschaltet, also
    /// kommt das Neue von rechts.
    private var forward: Bool {
        let order = DocumentMode.switchable
        guard let from = order.firstIndex(of: previous), let to = order.firstIndex(of: mode) else {
            return true
        }
        return to > from
    }

    // -----------------------------------------------------------------------

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            HStack(spacing: 10) {
                modeSwitch
                if archiveCount > 0 {
                    archivePill
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.primaryContainer)
        .foregroundStyle(palette.onPrimaryContainer)
        .clipShape(.rect(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private var titleRow: some View {
        HStack(spacing: 9) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 22))
            Text(strings[.appName])
                .font(AppType.actionLarge)
                .lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                Button {
                    onOpenSettings()
                } label: {
                    Label(strings[.menuSettings], systemImage: "gearshape")
                }
                // Die Version ist keine Handlung, sondern eine Auskunft. Sie bleibt
                // im Menue, weil man sie dort im Zweifel schneller findet als hinter
                // einem weiteren Bildschirm.
                Section {
                    Text(strings.format(.menuVersion, AppInfo.version))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(strings[.actionMenu])
        }
        .frame(minHeight: 48)
    }

    /// Der Umschalter der Dokumentart.
    ///
    /// Kein Haken im gewaehlten Abschnitt - ausdruecklich nicht gewuenscht. Damit
    /// traegt aber die Farbe allein die Auswahl, und das ist nach WCAG 1.4.1 zu
    /// wenig. Deshalb steht die gewaehlte Beschriftung **fett**. Dieselbe Auskunft,
    /// ohne Symbol.
    /// Bei den Bedienungshilfen-Schriftgroessen stehen die drei Beschriftungen
    /// **untereinander**.
    ///
    /// Nebeneinander gehen sie dort nicht: am Simulator mit der groessten
    /// Systemschrift stand da „ID | Passp… | Licence". Ein abgeschnittener
    /// Schalter ist schlimmer als ein hoher - er verschweigt, was er tut, und
    /// zwar genau demjenigen, der die grosse Schrift eingestellt hat, weil er
    /// schlecht sieht.
    ///
    /// Deshalb keine feinere Gewichtung, sondern ein anderer Aufbau. Die Grenze
    /// zieht `DynamicTypeSize/isAccessibilitySize` und nicht eine geratene
    /// Punktzahl.
    private var modeSwitch: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    ForEach(DocumentMode.switchable) { entry in
                        modeButton(entry, wrapping: true)
                    }
                }
            } else {
                horizontalModeSwitch
            }
        }
        .padding(3)
        .background(palette.surface.opacity(0.35), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.onPrimaryContainer.opacity(0.56), lineWidth: 1)
        }
    }

    private var horizontalModeSwitch: some View {
        WeightedRow(spacing: 4) {
            ForEach(DocumentMode.switchable) { entry in
                modeButton(entry, wrapping: false)
                    // Die Breite folgt der Wortlaenge, nicht gleichen Dritteln:
                    // „Führerschein" passt in ein Drittel nicht, und ein
                    // abgeschnittenes Wort ist als Schalterbeschriftung schlechter
                    // als ein schmalerer Nachbar. Der Sockel verhindert, dass
                    // „Pass" daneben auf ein Drittel dieser Breite schrumpft und
                    // kaum noch zu treffen ist.
                    .weight(WeightedRow.base + Double(strings[entry.labelKey].count))
            }
        }
    }

    private func modeButton(_ entry: DocumentMode, wrapping: Bool) -> some View {
        let selected = entry == mode
        return Button {
            previous = mode
            onModeChange(entry)
        } label: {
            Text(strings[entry.labelKey])
                .font(.footnote)
                .fontWeight(selected ? .bold : .medium)
                .lineLimit(wrapping ? nil : 1)
                .minimumScaleFactor(wrapping ? 1 : 0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    selected ? palette.surface : .clear,
                    in: .rect(cornerRadius: 18)
                )
                .foregroundStyle(
                    selected ? palette.primary : palette.onPrimaryContainer
                )
        }
        .buttonStyle(.plain)
    }


    /// Der Zugang zum Archiv, rechts neben dem Umschalter.
    ///
    /// Sichtbar ist nur die Anzahl. Wer die App aufmacht, soll nicht sofort sehen,
    /// wessen Ausweise gelesen wurden - die Namen stehen erst in der Liste, die man
    /// absichtlich oeffnet. Fuer die Vorlesefunktion steht der ganze Satz trotzdem
    /// da.
    private var archivePill: some View {
        Button(action: onOpenArchive) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.footnote)
                Text("\(archiveCount)").font(AppType.actionSmall)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(palette.onPrimaryContainer.opacity(0.56), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.onPrimaryContainer)
        .accessibilityLabel(strings.plural(.archiveOpen, archiveCount))
    }
}

/// Eine Zeile, deren Kinder ihre Breite nach einem Gewicht aufteilen.
///
/// `layoutPriority` waere das naechstliegende Mittel und ist das falsche: es
/// entscheidet nicht ueber Anteile, sondern darueber, **wer zuerst gekuerzt wird**
/// - mit dem Ergebnis, dass die beiden schmaleren Abschnitte des Umschalters auf
/// null gingen und nur „Führerschein" stehen blieb. Am Geraet gesehen, nicht
/// ausgedacht.
///
/// Diese Zeile teilt die verfuegbare Breite tatsaechlich im Verhaeltnis der
/// Gewichte auf, so wie `Modifier.weight` es unter Compose tat.
struct WeightedRow: Layout {

    /// Sockel der Abschnittsbreite. Zur Wortlaenge addiert; ohne ihn schrumpft
    /// „Pass" neben „Führerschein" auf ein Drittel dessen Breite.
    static let base: Double = 6

    var spacing: CGFloat = 0

    struct Cache {}

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) {
            $0 + $1.sizeThatFits(.unspecified).width
        }
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        guard !subviews.isEmpty else { return }

        let weights = subviews.map { $0[WeightKey.self] }
        let total = weights.reduce(0, +)
        let gaps = spacing * CGFloat(subviews.count - 1)
        let available = max(0, bounds.width - gaps)

        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let share = total > 0 ? weights[index] / total : 1 / Double(subviews.count)
            let width = available * CGFloat(share)
            subview.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }
}

private struct WeightKey: LayoutValueKey {
    static let defaultValue: Double = 1
}

extension View {
    /// Der Anteil, den dieses Kind in einer ``WeightedRow`` bekommt.
    func weight(_ value: Double) -> some View {
        layoutValue(key: WeightKey.self, value: value)
    }
}

/// Fassung und Bau der App, aus dem Bundle.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
