import SwiftUI
import IDReaderCore

/// Der Schluessel des Passes: drei Felder von der Datenseite.
///
/// Anders als bei der CIE lassen sich diese drei offline bestaetigen - jedes Feld
/// der zweiten MRZ-Zeile traegt eine Pruefziffer. Deshalb sagt die Maske hier
/// „Prüfziffern stimmen", und bei der CIE sagt sie das ausdruecklich nicht.
struct PassportInputScreen: View {

    @Bindable var model: ReaderModel
    let resetToken: Int
    let onScanRequested: () -> Void

    @State private var manualOpen = false
    @FocusState private var focused: Field?
    @Environment(\.palette) private var palette

    private enum Field { case number, birth, expiry }
    private var strings: Strings { model.strings }
    private var ready: Bool { model.passportInput.isValid && model.canReadChips }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                StepCard(
                    number: 1,
                    title: strings[.passportTitle],
                    subtitle: strings[.stepKeyPassSubtitle],
                    wideSubtitle: true
                ) {
                    if manualOpen {
                        manualEntry
                    } else {
                        photoPath
                    }
                }

                StepCard(
                    number: 2,
                    title: strings[.stepTapPassport],
                    badgeActive: ready
                ) {
                    if !model.canReadChips {
                        NoChipReaderNotice(strings: strings)
                    }
                    ReadButtons(
                        enabled: ready,
                        label: strings[.actionReadPassport],
                        fastLabel: strings[.actionReadCardFast],
                        onStartReading: model.startReading(withPhoto:)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        // Die Maske scrollt hier bewusst: mit stehender Tastatur passen drei
        // Textfelder und zwei Karten nicht auf einen Bildschirm, und ein Feld,
        // das unter der Tastatur liegt, ist nicht auszufuellen.
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: resetToken) {
            manualOpen = false
            focused = nil
        }
        .onChange(of: model.passportSource) { _, new in
            if new == .scanned {
                manualOpen = false
                focused = nil
            }
        }
    }

    // -----------------------------------------------------------------------

    @ViewBuilder private var photoPath: some View {
        DocumentGraphic(mode: .passport)
            .frame(maxWidth: 220)
            .frame(maxWidth: .infinity)

        PrimaryActionButton(
            title: strings[model.scanState == .working ? .passportScanWorking : .passportScan],
            systemImage: "camera.fill",
            busy: model.scanState == .working,
            action: onScanRequested
        )

        Text(strings[caption])
            .font(.footnote)
            .foregroundStyle(failed ? palette.error : palette.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)

        Divider().overlay(palette.outlineVariant)

        HStack(spacing: 8) {
            Text(strings[keyOrigin])
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
            Spacer(minLength: 0)
            Button {
                manualOpen = true
                focused = .number
            } label: {
                Text(strings[model.passportInput.isValid ? .actionChange : .actionEnterByHand])
                    .font(AppType.actionSmall)
                    .frame(minHeight: 40)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(palette.primary)
        }

        KeyValueRow(
            label: strings[.passportDocumentNumber],
            value: model.passportInput.documentNumber,
            placeholder: "–––––––––"
        )
        KeyValueRow(
            label: strings[.passportDateOfBirth],
            value: formatted(model.passportInput.dateOfBirth),
            placeholder: strings[.passportDatePlaceholder]
        )
        KeyValueRow(
            label: strings[.passportDateOfExpiry],
            value: formatted(model.passportInput.dateOfExpiry),
            placeholder: strings[.passportDatePlaceholder]
        )
    }

    @ViewBuilder private var manualEntry: some View {
        ManualDivider(
            label: strings[.manualDivider],
            backLabel: strings[.actionBackToPhoto],
            onUsePhoto: {
                manualOpen = false
                focused = nil
            }
        )

        field(
            label: strings[.passportDocumentNumber],
            text: model.passportInput.documentNumber,
            placeholder: "AA0000000",
            keyboard: .asciiCapable,
            field: .number,
            onChange: model.onPassportDocumentNumberChanged
        )
        field(
            label: strings[.passportDateOfBirth],
            text: model.passportInput.dateOfBirth,
            placeholder: strings[.passportDatePlaceholder],
            keyboard: .numberPad,
            field: .birth,
            onChange: model.onPassportDateOfBirthChanged
        )
        field(
            label: strings[.passportDateOfExpiry],
            text: model.passportInput.dateOfExpiry,
            placeholder: strings[.passportDatePlaceholder],
            keyboard: .numberPad,
            field: .expiry,
            onChange: model.onPassportDateOfExpiryChanged
        )
    }

    private func field(
        label: String,
        text: String,
        placeholder: String,
        keyboard: UIKeyboardType,
        field: Field,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
            TextField(placeholder, text: Binding(get: { text }, set: onChange))
                .font(AppType.monoField)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                .padding(12)
                .background(palette.surfaceContainer, in: .rect(cornerRadius: 10))
        }
    }

    /// TTMMJJJJ als TT.MM.JJJJ - dieselbe Schreibweise wie ueberall sonst.
    private func formatted(_ input: String) -> String? {
        guard input.count == AccessKey.dateInputLength else {
            return input.isEmpty ? nil : input
        }
        let c = Array(input)
        return "\(String(c[0..<2])).\(String(c[2..<4])).\(String(c[4..<8]))"
    }

    private var failed: Bool {
        [.notFound, .failed, .wrongSide, .ambiguous].contains(model.scanState)
    }

    private var caption: StringKey {
        switch model.scanState {
        case .notFound: .passportScanNotFound
        case .failed, .wrongSide, .ambiguous: .passportScanFailed
        default: .scanCaptionMrz
        }
    }

    /// Beim Pass darf die Maske sagen, dass die Erkennung bestaetigt ist - die drei
    /// Pruefziffern sind aufgegangen, bevor der Pass ueberhaupt angefasst wurde.
    private var keyOrigin: StringKey {
        if model.passportInput.isValid && model.passportSource == .scanned {
            return .passportScanConfirmed
        }
        if model.passportInput.isValid { return .keyTyped }
        return .keyMissing
    }
}
