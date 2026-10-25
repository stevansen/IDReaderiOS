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
    /// Der Hinweis, noch einmal angesehen. Getrennt von
    /// ``noticeAcknowledged``: die Bestaetigung bleibt, was sie war.
    @State private var noticeReview = false
    @State private var aboutOpen = false
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

    /// Die Ziele, die auf die Eingabemaske gelegt werden. Es ist immer hoechstens
    /// eins: Einstellungen, Info, Hinweis und Archiv werden alle von der
    /// Eingabemaske aus geoeffnet und nie voneinander.
    ///
    /// Der Pfad ist **abgeleitet** und nicht gespeichert - die Zustaende, die ihn
    /// ausmachen, gab es schon, und ein zweites Verzeichnis daneben liefe ihnen
    /// frueher oder spaeter auseinander. Zurueckgehen (Knopf oder Wischen vom Rand)
    /// meldet sich als leerer Pfad und schliesst, was offen war.
    private enum Route: Hashable { case archive, settings, about, notice }

    private var routes: Binding<[Route]> {
        Binding(
            get: {
                if settingsOpen { return [.settings] }
                if aboutOpen { return [.about] }
                if noticeReview { return [.notice] }
                if case .archive = model.stage { return [.archive] }
                return []
            },
            set: { new in
                guard new.isEmpty else { return }
                settingsOpen = false
                aboutOpen = false
                noticeReview = false
                if case .archive = model.stage { model.reset() }
            }
        )
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
        if !noticeAcknowledged {
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
            NavigationStack(path: routes) {
                stage
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Route.self) { route in
                        destination(route)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(
                                route == .notice ? palette.primaryContainer : palette.surfaceContainer,
                                for: .navigationBar
                            )
                            .toolbarBackground(.visible, for: .navigationBar)
                    }
            }
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .settings:
            SettingsScreen(model: model)
                .navigationTitle(strings[.menuSettings])
        case .about:
            AboutScreen(strings: strings)
                .navigationTitle(strings[.aboutTitle])
        case .notice:
            // Derselbe Bildschirm, aber ohne die Bestaetigung: `acknowledgeNotice`
            // wird hier **nicht** gerufen. Der vermerkte Zeitpunkt soll der der
            // ersten Zustimmung bleiben.
            FirstRunNotice(
                strings: strings,
                retentionDays: DocumentArchive.retentionDays,
                onAcknowledge: { noticeReview = false },
                reviewing: true
            )
        case .archive:
            ArchiveScreen(
                model: model,
                retentionDays: DocumentArchive.retentionDays,
                onExportSelected: {
                    exportingIds = model.selectedRecords().map(\.id)
                }
            )
        }
    }

    @ViewBuilder private var stage: some View {
        switch model.stage {
        case .idle, .archive:
            // Beim Archiv bleibt die Eingabemaske darunter stehen; das Archiv selbst
            // liegt als Ziel des Navigationsstapels obenauf.
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
                onShowNotice: { noticeReview = true },
                onShowAbout: { aboutOpen = true },
                strings: strings,
                onShowErrorSheet: {
                    #if DEBUG
                    model.zeigeFehlerblattZurPruefung()
                    #endif
                }
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
                retainsAllFields: model.retainsAllFields,
                strings: strings,
                onDone: model.reset,
                onReread: { model.rereadStored(document) },
                onShare: { exportingIds = [document.id] }
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
            .sheet(isPresented: Binding(
                get: { true },
                // Wegwischen ist dasselbe wie „Zurueck": sonst bliebe der Zustand
                // `.error` stehen, und der abgedunkelte Lesescreen ohne Blatt
                // darauf haette keinen Ausgang.
                set: { if !$0 { model.reset() } }
            )) {
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
