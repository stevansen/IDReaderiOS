import Foundation
import Observation
import SwiftUI
import UIKit
import IDReaderCore

/// Zustaende der App.
enum UIStage: Equatable {
    /// Eingabe, noch kein Lesevorgang gestartet.
    case idle
    /// Karte wird erwartet bzw. gerade gelesen.
    case reading(ReadStep)
    /// Ein Datensatz wird angezeigt.
    ///
    /// `fresh` ist true, wenn er gerade von der Karte kommt. Bei false stammt er
    /// aus dem Archiv - das muss die Oberflaeche zeigen, denn eine aufbewahrte
    /// Kopie kann veraltet sein, und ob die Karte inzwischen gesperrt wurde,
    /// weiss dieses Geraet nicht.
    case success(StoredDocument, fresh: Bool)
    /// Lesevorgang fehlgeschlagen.
    ///
    /// `lastStep` wird mitgefuehrt, weil der Fehler als Blatt ueber dem
    /// abgedunkelten Lesescreen erscheint - der muss dafuer weiterhin seinen
    /// letzten Stand zeigen koennen.
    case error(ReadErrorKind, lastStep: ReadStep)
    /// Liste der aufbewahrten Lesevorgaenge.
    case archive
}

/// Haelt Eingabe, Lesezustand und das Archiv.
///
/// Portiert aus `CieViewModel`. Aus `StateFlow` ist `@Observable` geworden, aus
/// `viewModelScope.launch(Dispatchers.IO)` ein `Task` - die Aufteilung selbst ist
/// dieselbe: der Zustand liegt hier und nicht in den Ansichten, weil die Kamera
/// die App in den Hintergrund schiebt und beim Zurueckkommen eine Drehung
/// dazwischen liegen kann. Im Modell ueberlebt die laufende Erkennung das.
@MainActor
@Observable
final class ReaderModel {

    // -----------------------------------------------------------------------
    // Zustand
    // -----------------------------------------------------------------------

    private(set) var stage: UIStage = .idle

    /// Welche Dokumentart gelesen wird.
    ///
    /// Bewusst kein Teil von ``stage``: der Zustand beschreibt, in welchem Schritt
    /// die App steckt, die Dokumentart dagegen ist eine Einstellung, die den
    /// Lesevorgang ueberdauert.
    private(set) var documentMode: DocumentMode = .identityCard

    private(set) var can = ""
    private(set) var canSource: InputSource = .typed

    private(set) var passportInput = PassportInput()
    private(set) var passportSource: InputSource = .typed

    var licenceInput = LicenceInput() {
        didSet {
            // Eine Meldung der letzten Aufnahme ist ueberholt, sobald von Hand
            // geaendert wird.
            if scanState != .idle { scanState = .idle }
        }
    }

    /// Stand einer laufenden oder gescheiterten Aufnahme, fuer alle Dokumentarten
    /// dieselbe: es kann ohnehin nur eine Aufnahme zugleich laufen.
    private(set) var scanState: ScanState = .idle

    /// Aufbewahrte Lesevorgaenge, neueste zuerst.
    private(set) var records: [StoredDocument] = []
    /// Angehakte Eintraege in der Liste.
    var selectedIds: Set<String> = []

    /// Ob das Geraet ueberhaupt NFC lesen kann.
    ///
    /// Anders als unter Android keine Frage nach einem Schalter: iOS hat keinen.
    let canReadChips: Bool

    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            settings.language = language
            strings = Strings(language: language)
        }
    }

    private(set) var strings: Strings

    // -----------------------------------------------------------------------

    private let archive: DocumentArchive
    private let reader: ChipDocumentReader
    private let settings: AppSettings

    private var readTask: Task<Void, Never>?

    /// Ob der naechste Lesevorgang das Lichtbild mitnimmt. Wird beim Start gesetzt
    /// und fuer „Erneut versuchen" beibehalten.
    private var readPhoto = false

    /// Verhindert, dass das Nachschlagen sofort wieder zuschlaegt, nachdem der
    /// Nutzer aus einem Archiveintrag heraus „neu lesen" gewaehlt hat - sonst
    /// landet man mit der vorbelegten CAN gleich wieder im alten Eintrag.
    private var suppressAutoJump = false

    init(
        archive: DocumentArchive,
        reader: ChipDocumentReader,
        settings: AppSettings = AppSettings()
    ) {
        self.archive = archive
        self.reader = reader
        self.settings = settings
        self.canReadChips = reader.isAvailable
        self.language = settings.language
        self.strings = Strings(language: settings.language)
        self.records = archive.load()
    }

    // -----------------------------------------------------------------------
    // Schluessel
    // -----------------------------------------------------------------------

    /// Die CAN ist genau sechsstellig und rein numerisch.
    var canIsValid: Bool { can.count == AccessKey.canLength }

    /// Der Schluessel fuer den naechsten Lesevorgang, oder nil wenn die Eingabe
    /// der aktuellen Dokumentart noch nicht reicht.
    private var accessKey: AccessKey? {
        switch documentMode {
        case .identityCard:
            let key = AccessKey.can(can)
            return key.isValid ? key : nil
        case .passport:
            return passportInput.accessKey
        // Die Fahrerlaubnis hat keinen Chip und deshalb keinen Schluessel.
        case .drivingLicence:
            return nil
        }
    }

    var canStartReading: Bool { accessKey != nil }

    // -----------------------------------------------------------------------
    // Dokumentart
    // -----------------------------------------------------------------------

    /// Wechselt die Dokumentart.
    ///
    /// Die Eingabe der anderen Art bleibt stehen - wer versehentlich umschaltet,
    /// soll nicht neu tippen muessen. Ein laufender Lesevorgang wird beendet, weil
    /// der Schluessel sonst nicht mehr zur Erwartung passt.
    func setDocumentMode(_ mode: DocumentMode) {
        guard documentMode != mode else { return }
        documentMode = mode
        // Eine Meldung der letzten Aufnahme galt fuer die andere Dokumentart.
        scanState = .idle
        if stage != .idle {
            cancelReading()
        }
    }

    // -----------------------------------------------------------------------
    // Aufnahme
    // -----------------------------------------------------------------------

    /// Startet die Auswertung einer Aufnahme.
    ///
    /// Ein Weg fuer alle Dokumentarten: fotografiert und erkannt wird gleich, nur
    /// was aus dem Text herauszulesen ist, haengt an der eingestellten Art. Beim
    /// Pass die MRZ, bei der CIE die CAN von der Vorderseite, beim Fuehrerschein
    /// die Felder der Vorderseite.
    func onPhotoTaken(_ image: UIImage) {
        scanState = .working
        let mode = documentMode
        Task {
            let text = await PhotoTextRecognizer.recognise(image)
            guard let text else {
                scanState = .failed
                return
            }
            switch mode {
            case .identityCard: scanState = readCan(text)
            case .passport: scanState = readMrz(text)
            case .drivingLicence: scanState = readLicence(text)
            }
        }
    }

    /// Die Kamera wurde ohne Aufnahme verlassen. Kein Fehler, keine Meldung.
    func onPhotoCancelled() {
        scanState = .idle
    }

    /// Sucht die CAN im erkannten Text und uebernimmt sie, wenn sie eindeutig ist.
    private func readCan(_ text: String) -> ScanState {
        switch CanScan.find(text) {
        case let .found(value):
            can = value
            canSource = .scanned
            // Danach dasselbe Nachschlagen wie beim Tippen. Es waere schwer zu
            // erklaeren, wenn der Weg ueber das Foto sich hier anders verhielte
            // als der ueber den Ziffernblock.
            jumpToKnownRecord()
            return .idle
        case .notFound: return .notFound
        case .ambiguous: return .ambiguous
        case .wrongSide: return .wrongSide
        }
    }

    /// Sucht den MRZ-Schluessel im erkannten Text.
    ///
    /// Die Datumsangaben kommen als JJMMTT aus der MRZ und muessen fuer die
    /// Anzeige in die Eingabeform TTMMJJJJ zurueck. Das Jahrhundert steckt nicht
    /// in der MRZ - beim Geburtsdatum wird dieselbe Annahme getroffen wie beim
    /// Lesen der Karte, beim Ablaufdatum liegt es immer in der Zukunft.
    private func readMrz(_ text: String) -> ScanState {
        guard case let .mrz(number, birth, expiry)? = MrzScan.findKey(text) else {
            return .notFound
        }
        passportInput = PassportInput(
            documentNumber: number,
            dateOfBirth: ReaderModel.toInputDate(birth, future: false),
            dateOfExpiry: ReaderModel.toInputDate(expiry, future: true)
        )
        passportSource = .scanned
        return .idle
    }

    /// Uebernimmt, was auf der Vorderseite zu lesen war.
    ///
    /// Anders als bei Karte und Pass wird hier nichts verworfen, wenn es
    /// unvollstaendig ist: jedes gefundene Feld erspart Tippen, und geprueft wird
    /// ohnehin von Hand.
    private func readLicence(_ text: String) -> ScanState {
        let fields = LicenceScan.read(text)
        if fields.isEmpty { return .notFound }
        licenceInput = LicenceInput.from(fields)
        return .idle
    }

    /// JJMMTT -> TTMMJJJJ.
    static func toInputDate(_ value: String, future: Bool) -> String {
        guard value.count == 6 else { return "" }
        let digits = Array(value)
        guard let year = Int(String(digits[0..<2])) else { return "" }
        let month = String(digits[2..<4])
        let day = String(digits[4..<6])

        let currentTwoDigit = Calendar.current.component(.year, from: Date()) % 100
        let century = future ? 2000 : (year > currentTwoDigit ? 1900 : 2000)
        return day + month + String(format: "%04d", century + year)
    }

    // -----------------------------------------------------------------------
    // Eingabe
    // -----------------------------------------------------------------------

    /// Haengt eine Ziffer an die CAN an; ueberzaehlige werden verworfen.
    func onDigitPressed(_ digit: Character) {
        guard digit.isNumber, can.count < AccessKey.canLength else { return }
        markTyped()
        can.append(digit)
        jumpToKnownRecord()
    }

    func onBackspacePressed() {
        markTyped()
        if !can.isEmpty { can.removeLast() }
    }

    func onClearPressed() {
        markTyped()
        can = ""
    }

    /// Ab jetzt ist die CAN von Hand eingegeben, und eine Meldung der letzten
    /// Aufnahme ist ueberholt.
    private func markTyped() {
        canSource = .typed
        scanState = .idle
    }

    func onPassportDocumentNumberChanged(_ value: String) {
        passportSource = .typed
        scanState = .idle
        // Grossschreibung und Filter hier, nicht in der Ansicht: die MRZ kennt nur
        // Grossbuchstaben und Ziffern.
        passportInput.documentNumber = String(
            value.uppercased().filter { $0.isLetter || $0.isNumber }
                .prefix(AccessKey.documentNumberLength)
        )
    }

    func onPassportDateOfBirthChanged(_ value: String) {
        passportSource = .typed
        scanState = .idle
        passportInput.dateOfBirth = ReaderModel.digits(value)
    }

    func onPassportDateOfExpiryChanged(_ value: String) {
        passportSource = .typed
        scanState = .idle
        passportInput.dateOfExpiry = ReaderModel.digits(value)
    }

    private static func digits(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(AccessKey.dateInputLength))
    }

    /// Ist die CAN vollstaendig und liegt zu ihr schon ein Eintrag im Archiv, wird
    /// sofort dieser Eintrag gezeigt - ohne die Karte auflegen zu muessen. Im
    /// Einsatz ist das der haeufige Fall: dieselbe Person noch einmal nachsehen,
    /// wenn die Karte schon wieder eingesteckt ist.
    private func jumpToKnownRecord() {
        guard can.count == AccessKey.canLength, !suppressAutoJump else { return }
        guard let known = records.first(where: { $0.can == can }) else { return }
        stage = .success(known, fresh: false)
    }

    // -----------------------------------------------------------------------
    // Lesen
    // -----------------------------------------------------------------------

    /// Startet den Lesevorgang.
    ///
    /// - Parameter withPhoto: DG2 mitlesen - dauert deutlich laenger.
    func startReading(withPhoto: Bool) {
        guard let key = accessKey else { return }
        readPhoto = withPhoto
        stage = .reading(.waitingForCard)
        run(key: key)
    }

    /// Nach einem Fehler direkt einen neuen Versuch starten.
    func retry() {
        guard let key = accessKey else { return }
        stage = .reading(.waitingForCard)
        run(key: key)
    }

    private func run(key: AccessKey) {
        readTask?.cancel()
        readTask = Task { [reader, archive] in
            var lastStep = ReadStep.waitingForCard
            do {
                let data = try await reader.read(key: key, readPhoto: readPhoto) { [weak self] step in
                    guard let self, case .reading = self.stage else { return }
                    self.stage = .reading(step)
                }
                lastStep = .done
                try Task.checkCancellation()

                let document = StoredDocument(
                    data: data,
                    storedAt: currentTimeMillis(),
                    // Auf iOS liefert die Sitzung keine stabile Tag-Kennung, und
                    // Ausweisdokumente ziehen sie nach ICAO 9303 bei jedem
                    // Auflegen ohnehin neu.
                    cardId: nil,
                    // Nur die CAN wird aufbewahrt. Fuer einen Pass bleibt das Feld
                    // leer: der MRZ-Schluessel besteht aus Dokumentnummer,
                    // Geburts- und Ablaufdatum, also aus genau den Personendaten,
                    // die das Archiv schuetzen soll.
                    can: key.canValue ?? ""
                )
                records = archive.add(document)
                stage = .success(document, fresh: true)
            } catch is CancellationError {
                return
            } catch let error as ReadError {
                stage = .error(error.kind, lastStep: lastStep)
            } catch {
                stage = .error(.unknown, lastStep: lastStep)
            }
        }
    }

    /// Abbrechen im Lesescreen.
    func cancelReading() {
        reader.abort()
        readTask?.cancel()
        readTask = nil
        // Wer einen Lesevorgang abbricht, kommt zu einer Maske zurueck, auf der die
        // Meldung der letzten Aufnahme nichts mehr aussagt.
        scanState = .idle
        stage = .idle
    }

    /// Legt die erfasste Fahrerlaubnis ab.
    ///
    /// Ohne Lesevorgang und ohne Pruefung - der Datensatz ist, was in der Maske
    /// steht. Er traegt ``RecordProvenance/photo``, und daran haengt alles
    /// Weitere: keine Siegel, keine Echtheitszeile im Export, und im Bericht ein
    /// Hinweis, dass hier nichts bestaetigt ist.
    func saveLicence() {
        guard licenceInput.isComplete else { return }
        let document = StoredDocument(
            data: licenceInput.toDocumentData(),
            storedAt: currentTimeMillis(),
            cardId: nil,
            can: ""
        )
        records = archive.add(document)
        licenceInput = LicenceInput()
        stage = .success(document, fresh: true)
    }

    /// Zurueck zur Eingabe.
    ///
    /// Die Daten im Arbeitsspeicher werden freigegeben; die verschluesselte Kopie
    /// im Archiv bleibt bis zum Verfall oder bis sie geloescht wird.
    func reset() {
        reader.abort()
        readTask?.cancel()
        readTask = nil
        can = ""
        // Die Dokumentnummer ist selbst ein Personendatum und hat nach dem
        // Abschluss nichts mehr im Eingabefeld zu suchen - dieselbe Begruendung wie
        // beim Leeren der CAN.
        passportInput = PassportInput()
        canSource = .typed
        passportSource = .typed
        scanState = .idle
        suppressAutoJump = false
        stage = .idle
    }

    // -----------------------------------------------------------------------
    // Archiv
    // -----------------------------------------------------------------------

    func openArchive() {
        selectedIds = []
        stage = .archive
    }

    func openRecord(_ document: StoredDocument) {
        stage = .success(document, fresh: false)
    }

    /// Aus einem Archiveintrag heraus dieselbe Karte neu lesen.
    ///
    /// Die CAN wird vorbelegt und der Nutzer landet wieder auf der Eingabe - dort
    /// kann er entscheiden, ob mit oder ohne Lichtbild gelesen wird.
    func rereadStored(_ document: StoredDocument) {
        // Auf die Dokumentart des Eintrags umschalten, sonst landet man bei einem
        // Pass in der CAN-Maske und wundert sich.
        documentMode = DocumentMode.of(document.data)
        // Vorbelegen laesst sich nur die CAN. Der MRZ-Schluessel wird bewusst nicht
        // aufbewahrt, also muss er neu eingegeben werden.
        can = document.can
        canSource = .typed
        // Eine Meldung der letzten Aufnahme gilt nicht fuer eine Eingabe, die
        // gerade aus dem Archiv vorbelegt wurde.
        scanState = .idle
        suppressAutoJump = true
        stage = .idle
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    /// Hakt alle an oder - wenn schon alle angehakt sind - alle ab.
    func toggleSelectAll() {
        let all = Set(records.map(\.id))
        selectedIds = selectedIds.isSuperset(of: all) ? [] : all
    }

    func clearSelection() {
        selectedIds = []
    }

    /// Die angehakten Eintraege in der Reihenfolge der Liste.
    func selectedRecords() -> [StoredDocument] {
        records.filter { selectedIds.contains($0.id) }
    }

    func deleteSelected() {
        guard !selectedIds.isEmpty else { return }
        let remaining = archive.remove(ids: selectedIds)
        records = remaining
        selectedIds = []
        if remaining.isEmpty { stage = .idle }
    }

    func deleteRecord(_ id: String) {
        records = archive.remove(ids: [id])
        selectedIds.remove(id)
    }

    /// Verbleibende Aufbewahrungstage eines Eintrags.
    func remainingDays(_ storedAt: Int64) -> Int {
        archive.remainingDays(storedAt: storedAt)
    }

    // -----------------------------------------------------------------------
    // Erster Start
    // -----------------------------------------------------------------------

    var noticeAcknowledged: Bool { settings.noticeAcknowledged }

    func acknowledgeNotice() {
        settings.acknowledgeNotice()
    }

    var shareEmail: String {
        get { settings.shareEmail }
        set { settings.shareEmail = newValue }
    }

    var exportFormat: ExportFormat {
        get { settings.exportFormat }
        set { settings.exportFormat = newValue }
    }

    /// Die Farbwelt, die gerade gilt.
    ///
    /// Liegt ein gelesenes Dokument auf dem Schirm, gilt dessen Art und nicht die
    /// Einstellung: ein Pass aus dem Archiv soll braun sein, auch wenn als
    /// naechstes eine Karte gelesen werden soll. Sonst haette die Farbe nichts mit
    /// dem zu tun, was man gerade ansieht.
    var colourMode: DocumentMode {
        if case let .success(document, _) = stage {
            return DocumentMode.of(document.data)
        }
        return documentMode
    }
}

extension AccessKey {
    var canValue: String? {
        if case let .can(value) = self { return value }
        return nil
    }
}
