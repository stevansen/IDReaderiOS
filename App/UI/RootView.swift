import SwiftUI
import IDReaderCore

/// Waehlt anhand des Modellzustands den passenden Bildschirm.
///
/// Das Gegenstueck zu `CieApp` der Android-Fassung, und mit derselben Aufteilung:
/// die Kamera haengt hier oben und nicht in den Masken, weil das Kameraprogramm
/// den eigenen Bildschirm in den Hintergrund schiebt und der Empfaenger des
/// Ergebnisses die Rueckkehr an derselben Stelle erwarten muss.
struct RootView: View {

    @Bindable var model: ReaderModel

    @State private var settingsOpen = false
    @State private var noticeAcknowledged: Bool
    @State private var cameraOpen = false
    @State private var exportingIds: [String] = []

    @Environment(\.colorScheme) private var colorScheme

    init(model: ReaderModel) {
        self.model = model
        self.noticeAcknowledged = model.noticeAcknowledged
    }

    private var strings: Strings { model.strings }
    private var palette: DocumentPalette {
        DocumentPalette.of(model.colourMode, dark: colorScheme == .dark)
    }

    /// Gemerkt werden die Kennungen, nicht die Datensaetze: ist ein Eintrag
    /// inzwischen abgelaufen oder geloescht, faellt er dabei von selbst aus dem
    /// Export.
    private var exporting: [StoredDocument] {
        model.records.filter { exportingIds.contains($0.id) }
    }

    var body: some View {
        content
            .environment(\.palette, palette)
            .background(palette.background)
            .tint(palette.primary)
            .fullScreenCover(isPresented: $cameraOpen) {
                CameraPicker { image in
                    cameraOpen = false
                    if let image {
                        model.onPhotoTaken(image)
                    } else {
                        model.onPhotoCancelled()
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: Binding(
                get: { !exporting.isEmpty },
                set: { if !$0 { exportingIds = [] } }
            )) {
                ShareSheetScreen(
                    documents: exporting,
                    model: model,
                    onDismiss: { exportingIds = [] }
                )
                .environment(\.palette, palette)
            }
    }

    @ViewBuilder private var content: some View {
        if settingsOpen {
            SettingsScreen(model: model, onBack: { settingsOpen = false })
        } else if !noticeAcknowledged {
            // Vor allem anderen: es soll niemand ein Dokument gelesen haben, bevor
            // er weiss, dass er dafuer verantwortlich ist.
            FirstRunNotice(
                strings: strings,
                retentionDays: DocumentArchive.retentionDays,
                onAcknowledge: {
                    model.acknowledgeNotice()
                    noticeAcknowledged = true
                }
            )
        } else {
            stage
        }
    }

    @ViewBuilder private var stage: some View {
        switch model.stage {
        case .idle:
            // Drei voneinander unabhaengige Eingabemasken, ausgewaehlt ueber die
            // Dokumentart. Keine gemeinsame Maske mit Schaltern darin: die
            // CAN-Maske lebt von ihrem eigenen Ziffernblock ohne Systemtastatur,
            // der Pass braucht Textfelder mit einer.
            DocumentInputScaffold(
                mode: model.documentMode,
                onModeChange: model.setDocumentMode,
                archiveCount: model.records.count,
                onOpenArchive: model.openArchive,
                onOpenSettings: { settingsOpen = true },
                strings: strings
            ) { shown, resetToken in
                switch shown {
                case .identityCard:
                    CanInputScreen(
                        model: model,
                        resetToken: resetToken,
                        onScanRequested: { cameraOpen = true }
                    )
                case .passport:
                    PassportInputScreen(
                        model: model,
                        resetToken: resetToken,
                        onScanRequested: { cameraOpen = true }
                    )
                case .drivingLicence:
                    LicenceScreen(
                        model: model,
                        onScanRequested: { cameraOpen = true }
                    )
                }
            }

        case let .reading(step):
            ReadingScreen(
                step: step,
                mode: model.documentMode,
                strings: strings,
                onCancel: model.cancelReading
            )

        case let .success(document, fresh):
            ResultScreen(
                document: document,
                fresh: fresh,
                retentionDays: DocumentArchive.retentionDays,
                strings: strings,
                onDone: model.reset,
                onReread: { model.rereadStored(document) },
                onShare: { exportingIds = [document.id] }
            )

        case .archive:
            ArchiveScreen(
                model: model,
                retentionDays: DocumentArchive.retentionDays,
                onBack: model.reset,
                onExportSelected: {
                    exportingIds = model.selectedRecords().map(\.id)
                }
            )

        case let .error(kind, lastStep, detail):
            // Der Fehler legt sich als Blatt ueber den abgedunkelten Lesescreen -
            // der Vorgang wurde unterbrochen, nicht verlassen.
            ReadingScreen(
                step: lastStep,
                mode: model.documentMode,
                strings: strings,
                dimmed: true,
                onCancel: model.reset
            )
            .sheet(isPresented: .constant(true)) {
                ErrorSheet(
                    kind: kind,
                    detail: detail,
                    strings: strings,
                    onRetry: model.retry,
                    onBack: model.reset
                )
                .environment(\.palette, palette)
                .presentationBackground(palette.surface)
            }
        }
    }
}
