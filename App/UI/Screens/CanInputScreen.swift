import SwiftUI
import IDReaderCore

/// Eingabe der Card Access Number.
///
/// Statt eines Textfelds mit Systemtastatur: sechs Ziffernfelder und ein eigener
/// Ziffernblock. Das hat zwei Gruende - die Eingabe ist immer numerisch und genau
/// sechsstellig, und der Bildschirm springt nicht, weil keine Systemtastatur ein-
/// und ausfaehrt.
struct CanInputScreen: View {

    @Bindable var model: ReaderModel
    let resetToken: Int
    let onScanRequested: () -> Void

    /// Die Handeingabe ist eingeklappt, bis jemand sie oeffnet; der Zaehler aus dem
    /// Geruest klappt sie wieder ein.
    ///
    /// Mit der sechsten Ziffer klappt sie **nicht** zu. Frueher tat sie das, weil
    /// der Leseknopf sonst hinter ihr gelegen haette - inzwischen steht Schritt 2
    /// daneben im Bild, und dort geht der Knopf einfach an. Wer sechs Ziffern
    /// getippt hat, will lesen und nicht erst wieder eine Ansicht vorgesetzt
    /// bekommen, die er gerade verlassen hat.
    @State private var manualOpen = false
    /// Solange nichts eingegeben ist, wandert eine Betonung ueber die CAN auf der
    /// Karte. Sobald getippt wird, hoert das auf - dann ist verstanden, worum es
    /// geht, und eine laufende Bewegung waere nur noch Unruhe.
    @State private var demoIndex: Int? = 0

    @Environment(\.palette) private var palette

    private var strings: Strings { model.strings }
    private var ready: Bool { model.canIsValid && model.canReadChips }

    var body: some View {
        VStack(spacing: 10) {
            StepCard(
                number: 1,
                title: strings[.stepKeyCardTitle],
                subtitle: strings[.canHint]
            ) {
                if manualOpen {
                    manualEntry
                } else {
                    photoPath
                }
            }

            // Schritt 2 ist eine Karte wie Schritt 1 - gleich eingerueckt, gleicher
            // Rahmen - und der Leseknopf steht darin. Er gehoert zu diesem Schritt
            // und nicht in eine eigene Leiste am Fuss.
            StepCard(
                number: 2,
                title: strings[.stepTapCard],
                badgeActive: ready
            ) {
                if !model.canReadChips {
                    NoChipReaderNotice(strings: strings)
                }
                ReadButtons(
                    enabled: ready,
                    label: strings[.actionReadCard],
                    fastLabel: strings[.actionReadCardFast],
                    onStartReading: model.startReading(withPhoto:)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .onChange(of: resetToken) { manualOpen = false }
        .onChange(of: model.canSource) { _, new in
            // Am Uebergang festgemacht, nicht am Wert: `canSource` bleibt nach einer
            // gelungenen Aufnahme `scanned` stehen, und wer danach die Handeingabe
            // oeffnete, bekaeme sie sonst sofort wieder zugeklappt.
            if new == .scanned { manualOpen = false }
        }
        .task(id: model.can.isEmpty) {
            guard model.can.isEmpty else {
                demoIndex = nil
                return
            }
            var index = 0
            while !Task.isCancelled {
                demoIndex = index
                index = (index + 1) % AccessKey.canLength
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    // -----------------------------------------------------------------------

    @ViewBuilder private var photoPath: some View {
        // Kleiner als randbreit: das Bild soll zeigen, wo die Ziffern stehen, und
        // nicht die halbe Maske belegen.
        DocumentGraphic(mode: .identityCard, highlightDigit: demoIndex)
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)

        PrimaryActionButton(
            title: strings[model.scanState == .working ? .canScanWorking : .canScan],
            systemImage: "camera.fill",
            busy: model.scanState == .working,
            action: onScanRequested
        )

        // Eine Zeile Beschreibung unter dem Knopf. Im Fehlerfall ist sie die
        // Stelle, an der die Meldung steht.
        Text(strings[caption])
            .font(.footnote)
            .foregroundStyle(failed ? palette.error : palette.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)

        Divider().overlay(palette.outlineVariant)

        HStack(spacing: 8) {
            if model.canIsValid && model.canSource == .scanned {
                Image(systemName: "camera")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            Text(strings[keyOrigin])
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
            Spacer(minLength: 0)
            Button {
                manualOpen = true
            } label: {
                Text(strings[model.canIsValid ? .actionChange : .actionEnterByHand])
                    .font(AppType.actionSmall)
                    .frame(minHeight: 40)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(palette.primary)
        }

        KeyValueRow(
            label: strings[.canLabel],
            value: model.canIsValid ? model.can : nil,
            placeholder: "––––––",
            valueFont: AppType.monoCan
        )
    }

    @ViewBuilder private var manualEntry: some View {
        ManualDivider(
            label: strings[.manualDivider],
            backLabel: strings[.actionBackToPhoto],
            onUsePhoto: { manualOpen = false }
        )
        DigitBoxes(
            can: model.can,
            scanned: model.canSource == .scanned,
            strings: strings
        )
        Keypad(
            onDigit: model.onDigitPressed,
            onBackspace: model.onBackspacePressed,
            onClear: model.onClearPressed,
            strings: strings
        )
    }

    private var failed: Bool {
        [.notFound, .wrongSide, .ambiguous, .failed].contains(model.scanState)
    }

    private var caption: StringKey {
        switch model.scanState {
        case .notFound: .canScanNotFound
        case .wrongSide: .canScanWrongSide
        case .ambiguous: .canScanAmbiguous
        case .failed: .canScanFailed
        default: .scanCaptionCan
        }
    }

    private var keyOrigin: StringKey {
        if model.canIsValid && model.canSource == .scanned { return .keyFromPhoto }
        if model.canIsValid { return .keyTyped }
        return .keyMissing
    }
}

/// Sechs Ziffernfelder; das naechste freie bekommt eine Betonung.
private struct DigitBoxes: View {
    let can: String
    let scanned: Bool
    let strings: Strings

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<AccessKey.canLength, id: \.self) { index in
                let digit = index < can.count ? String(Array(can)[index]) : ""
                let active = index == can.count
                // Aus dem Foto uebernommene Ziffern stehen auf getoenter Flaeche.
                // Anders als beim Pass darf hier aber kein Haken stehen: die CAN hat
                // keine Pruefziffer, es ist nichts bestaetigt.
                let filled = !digit.isEmpty
                Text(digit)
                    .font(AppType.monoDigitBox)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        scanned && filled ? palette.secondaryContainer : palette.surfaceContainer,
                        in: .rect(cornerRadius: 10)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                active ? palette.primary : palette.outlineVariant,
                                lineWidth: active ? 2 : 1
                            )
                    }
                    .accessibilityLabel(
                        strings.format(filled ? .cdDigitFilled : .cdDigitEmpty, index + 1)
                    )
            }
        }
    }
}

/// Der eigene Ziffernblock.
///
/// Keine Systemtastatur: die Eingabe ist immer numerisch und genau sechsstellig,
/// und der Bildschirm soll nicht springen, waehrend eine Tastatur ein- und
/// ausfaehrt.
private struct Keypad: View {
    let onDigit: (Character) -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let strings: Strings

    @Environment(\.palette) private var palette

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(1...3, id: \.self) { column in
                        key("\(row * 3 + column)")
                    }
                }
            }
            GridRow {
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .accessibilityLabel(strings[.actionClearAll])
                key("0")
                Button(action: onBackspace) {
                    Image(systemName: "delete.left")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .accessibilityLabel(strings[.actionBackspace])
            }
        }
        .buttonStyle(KeypadButtonStyle(palette: palette))
    }

    private func key(_ digit: String) -> some View {
        Button {
            onDigit(Character(digit))
        } label: {
            Text(digit)
                .font(.system(size: 22, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    let palette: DocumentPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.onSurface)
            .background(
                configuration.isPressed ? palette.surfaceContainerHigh : palette.surfaceContainer,
                in: .rect(cornerRadius: 12)
            )
    }
}

/// Geteilter Knopf: links mit Lichtbild, rechts der schnelle Weg ohne.
///
/// Das Lichtbild liegt in DG2 und ist die mit Abstand groesste Datengruppe - es zu
/// lesen dauert ein Mehrfaches. Trotzdem ist es der breite Standardknopf: wer im
/// Einsatz eine Person vor sich hat, will das Gesicht vergleichen koennen, und ein
/// Datensatz ohne Bild nuetzt dabei wenig. Der schnelle Weg bleibt als schmaler
/// Zusatz daneben. Beide zusammen bilden optisch einen Knopf: aussen rund, innen
/// kantig.
struct ReadButtons: View {
    let enabled: Bool
    let label: String
    let fastLabel: String
    let onStartReading: (Bool) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            Button {
                onStartReading(true)
            } label: {
                Label(label, systemImage: "person.crop.square")
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .background(
                enabled ? palette.primary : palette.surfaceContainerHigh,
                in: .rect(topLeadingRadius: 26, bottomLeadingRadius: 26,
                          bottomTrailingRadius: 6, topTrailingRadius: 6)
            )

            Button {
                onStartReading(false)
            } label: {
                Image(systemName: "forward.fill")
                    .frame(width: 62)
                    .frame(minHeight: 52)
            }
            .background(
                enabled ? palette.primary : palette.surfaceContainerHigh,
                in: .rect(topLeadingRadius: 6, bottomLeadingRadius: 6,
                          bottomTrailingRadius: 26, topTrailingRadius: 26)
            )
            .accessibilityLabel(fastLabel)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? palette.onPrimary : palette.onSurfaceVariant)
        .disabled(!enabled)
    }
}

/// Ein grosser Knopf mit Zeichen, der auch „laeuft gerade" zeigen kann.
struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var busy = false
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title).lineLimit(1)
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.onPrimaryContainer)
        .background(palette.primaryContainer, in: .rect(cornerRadius: 14))
        .disabled(busy)
    }
}

/// Hinweis, wenn das Geraet keine Ausweise lesen kann.
///
/// Nicht dasselbe wie die Android-Meldung „NFC ist ausgeschaltet": iOS hat keinen
/// Schalter dafuer. Es kann nur sein, dass das Geraet es gar nicht kann - und dann
/// hilft keine Einstellung, sondern nur ein anderes Geraet.
struct NoChipReaderNotice: View {
    let strings: Strings

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(strings[.noNfcTitle]).font(.subheadline.weight(.medium))
                Text(strings[.noNfcMessage]).font(.footnote)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.errorContainer, in: .rect(cornerRadius: 12))
        .foregroundStyle(palette.onErrorContainer)
    }
}
