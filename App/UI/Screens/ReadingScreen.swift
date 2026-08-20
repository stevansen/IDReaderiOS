import SwiftUI
import IDReaderCore

/// Der Augenblick des Auflegens.
///
/// Vollbild, pulsierende Ringe hinter einer schwebenden Karte, die vier Phasen
/// als Checkliste, ein Fortschrittsbalken. Bewusst ruhig: die Karte darf waehrend
/// des Lesens nicht bewegt werden, und ein unruhiger Bildschirm laedt genau dazu
/// ein.
///
/// Je Phase genau eine Beschriftung, unveraendert von Anfang bis Ende. Frueher
/// wechselte der Text zwischen „wird aufgebaut" und „aufgebaut" - dadurch aenderte
/// sich die Zeilenlaenge, Zeilen brachen um und die ganze Liste sprang waehrend des
/// Lesens. Den Zustand zeigt allein das Symbol davor.
struct ReadingScreen: View {

    let step: ReadStep
    let mode: DocumentMode
    let strings: Strings
    var dimmed = false
    let onCancel: () -> Void

    @Environment(\.palette) private var palette
    @State private var pulse = false

    var body: some View {
        ZStack {
            palette.tapBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(palette.tapAccent.opacity(0.18), lineWidth: 1.5)
                            .frame(width: 150 + CGFloat(ring) * 55)
                            .scaleEffect(pulse ? 1.06 : 0.97)
                            .animation(
                                .easeInOut(duration: 1.8)
                                    .repeatForever()
                                    .delay(Double(ring) * 0.25),
                                value: pulse
                            )
                    }
                    DocumentGraphic(mode: mode)
                        .frame(width: 190)
                        .shadow(radius: 18, y: 8)
                }

                VStack(spacing: 6) {
                    Text(strings[mode == .passport ? .readingTitlePassport : .readingTitle])
                        .font(.title2.weight(.semibold))
                    Text(strings[
                        mode == .passport ? .readingInstructionPassport : .readingInstruction
                    ])
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.onTapBackgroundMuted)
                }
                .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ReadPhase.allCases, id: \.self) { phase in
                        phaseRow(phase)
                    }
                }
                .frame(maxWidth: 320)

                ProgressView(value: step.progress)
                    .tint(palette.tapAccent)
                    .frame(maxWidth: 320)

                Spacer()

                Button(action: onCancel) {
                    Text(strings[.actionCancel])
                        .font(AppType.actionLarge)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.onTapBackground)
                .overlay { Capsule().stroke(palette.onTapBackgroundMuted, lineWidth: 1) }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .foregroundStyle(palette.onTapBackground)
        }
        .opacity(dimmed ? 0.45 : 1)
        .onAppear { pulse = true }
    }

    private func phaseRow(_ phase: ReadPhase) -> some View {
        let order = ReadPhase.allCases
        let current = order.firstIndex(of: step.phase) ?? 0
        let index = order.firstIndex(of: phase) ?? 0
        let done = index < current || step == .done
        let running = index == current && step != .done

        return HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill"
                                   : (running ? "circle.dotted" : "circle"))
                .foregroundStyle(done ? palette.tapDone : palette.onTapBackgroundMuted)
            Text(strings[label(phase)])
                .font(.subheadline)
                .foregroundStyle(running ? palette.onTapBackground : palette.onTapBackgroundMuted)
            Spacer(minLength: 0)
        }
    }

    private func label(_ phase: ReadPhase) -> StringKey {
        switch phase {
        case .connect: .phaseConnect
        case .secure: .phaseSecure
        case .data: .phaseData
        case .verify: .phaseVerify
        }
    }
}

/// Fehlermeldung als Blatt ueber dem abgedunkelten Lesescreen.
///
/// Der Lesescreen bleibt bewusst sichtbar: der Fehler ist eine Unterbrechung des
/// Vorgangs, kein neuer Ort. „Erneut versuchen" fuehrt damit sichtbar dorthin
/// zurueck, wo man war.
struct ErrorSheet: View {

    let kind: ReadErrorKind
    let strings: Strings
    let onRetry: () -> Void
    let onBack: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.error)
                    .frame(width: 44, height: 44)
                    .background(palette.errorContainer, in: .rect(cornerRadius: 14))
                Text(strings[.errorTitle]).font(.headline)
            }

            Text(strings[kind.messageKey]).font(.body)

            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text(strings[.actionBack])
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .overlay { Capsule().stroke(palette.outline, lineWidth: 1) }

                Button(action: onRetry) {
                    Label(strings[.actionRetry], systemImage: "arrow.clockwise")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.onPrimary)
                .background(palette.primary, in: .capsule)
                .layoutPriority(1.4)
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .presentationDetents([.height(300)])
    }
}
