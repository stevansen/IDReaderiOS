import SwiftUI
import IDReaderCore

/// Der Eintritt.
///
/// Hier wird zusammengesteckt, was die App braucht: das Archiv mit seinem
/// Schluessel aus dem Schluesselbund, der Chipleser mit den Vertrauensankern, und
/// das Modell darueber. Absichtlich an einer Stelle und nicht verstreut - wer
/// wissen will, was diese App anfasst, soll eine Datei lesen muessen.
@main
struct IDReaderApp: App {

    @State private var model: ReaderModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        let strings = Strings(language: settings.language)

        // Scheitert das Anlegen der Archivdatei, laeuft die App weiter - mit einem
        // Archiv, das nichts behaelt. Das ist besser als ein Start, der abbricht:
        // Lesen und Anzeigen gehen auch ohne Aufbewahrung, und die Meldung dafuer
        // steht schon im Schreibweg.
        let file = (try? DocumentArchive.defaultFile())
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("archive.bin")

        let archive = DocumentArchive(file: file, keys: KeychainArchiveKeyStore())
        #if DEBUG
        // Nur Fehlerarten, nie Inhalte - hier laufen Personendaten durch.
        archive.log = { print("[archive] \($0)") }
        #endif

        let reader = CoreNFCChipReader(
            pace: UnavailablePACEEngine(),
            trustAnchors: CscaTrustStore.load(),
            strings: strings
        )

        _model = State(initialValue: ReaderModel(
            archive: archive,
            reader: reader,
            settings: settings
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                // Die Sprache legt sich ueber alles - auch ueber Blaetter und
                // Dialoge -, und `CieExport` holt seine Texte aus demselben
                // Katalog. Unter Android war das ein eigener Context; hier reicht
                // es, das Modell den Katalog fuehren zu lassen.
                .environment(\.locale, Locale(identifier: model.strings.resolved))
                .overlay {
                    // Kein Abbild dieser App im App-Umschalter: dort laege sonst der
                    // zuletzt gezeigte Datensatz samt Lichtbild als Schnappschuss im
                    // Systemspeicher.
                    //
                    // Bewusst **kein** vollstaendiger Bildschirmschutz: das verboete
                    // auch das absichtliche Bildschirmfoto, mit dem Tester Fehler
                    // melden - der Schnappschuss hingegen entsteht ungefragt.
                    // Dieselbe Abwaegung wie in der Android-Fassung, dort
                    // `setRecentsScreenshotEnabled(false)` statt `FLAG_SECURE`.
                    if scenePhase != .active {
                        PrivacyCurtain(strings: model.strings)
                    }
                }
        }
    }
}

/// Was im App-Umschalter zu sehen ist.
struct PrivacyCurtain: View {
    let strings: Strings

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial)
            VStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 34))
                Text(strings[.appName]).font(AppType.actionLarge)
            }
            .foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }
}
