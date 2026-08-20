import CoreNFC
import Foundation
import IDReaderCore

/// Liest ein Ausweisdokument ueber CoreNFC.
///
/// ## Wo sich iOS von Android unterscheidet
///
/// Die Android-Fassung haelt den Reader-Mode dauerhaft an
/// (`NfcAdapter.enableReaderMode`) und bekommt jede aufgelegte Karte gemeldet -
/// auch im Ruhezustand, weshalb sie eine bekannte Karte wiedererkennen kann,
/// ohne dass jemand etwas antippt.
///
/// Auf iOS geht das nicht. `NFCTagReaderSession` wird ausdruecklich gestartet,
/// zeigt ein Systemblatt und endet nach einem Durchgang. Daraus folgt zweierlei,
/// und beides ist bewusst so und nicht vergessen:
///
/// * Es gibt kein Wiedererkennen einer aufgelegten Karte im Ruhezustand. Der
///   entsprechende Weg der Android-Fassung entfaellt; das Nachschlagen ueber die
///   eingetippte CAN bleibt und ist im Einsatz ohnehin der haeufigere Fall.
/// * Die Frage „ist NFC eingeschaltet?" gibt es nicht. iOS kennt keinen
///   Schalter dafuer; `readingAvailable` sagt nur, ob das Geraet es kann. Die
///   Meldung „NFC ist ausgeschaltet" kommt deshalb nie vor - der Text bleibt im
///   Katalog, damit die drei Sprachfassungen deckungsgleich bleiben.
///
/// ## Was diese Klasse selbst tut
///
/// Alles bis zur gesicherten Verbindung: Sitzung aufbauen, `EF.CardAccess` ueber
/// die Kurzkennung lesen, den `PACEInfo` daraus ziehen. Der Handschlag selbst
/// geht an ``PACEEngine`` - siehe dort, warum.
@MainActor
final class CoreNFCChipReader: NSObject, ChipDocumentReader {

    private let pace: PACEEngine
    private let trustAnchors: [Data]

    /// Der Text im Systemblatt. Die Sitzung zeigt ihn, nicht die App.
    private let strings: Strings

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<DocumentData, Error>?

    init(pace: PACEEngine, trustAnchors: [Data], strings: Strings) {
        self.pace = pace
        self.trustAnchors = trustAnchors
        self.strings = strings
        super.init()
    }

    var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func read(
        key: AccessKey,
        readPhoto: Bool,
        onProgress: @escaping (ReadStep) -> Void
    ) async throws -> DocumentData {
        guard isAvailable else { throw ReadError(.unsupportedTag, "kein NFC") }

        onProgress(.waitingForCard)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.pending = Pending(key: key, readPhoto: readPhoto, onProgress: onProgress)

            // Auf dem Hauptfaden zurueckrufen. Die Vorgabe ist ein eigener Faden,
            // und dann waeren Sitzung und Tag von zwei Faeden aus zu erreichen -
            // beides gibt CoreNFC nicht als threadsicher heraus.
            let session = NFCTagReaderSession(
                pollingOption: [.iso14443],
                delegate: self,
                queue: .main
            )
            session?.alertMessage = strings[
                key.isCan ? .stepTapCard : .stepTapPassport
            ]
            self.session = session
            session?.begin()
        }
    }

    func abort() {
        session?.invalidate()
        session = nil
        finish(.failure(ReadError(.connectionLost, "abgebrochen")))
    }

    // -----------------------------------------------------------------------

    private struct Pending {
        let key: AccessKey
        let readPhoto: Bool
        let onProgress: (ReadStep) -> Void
    }

    private var pending: Pending?

    private func finish(_ result: Result<DocumentData, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.pending = nil
        continuation.resume(with: result)
    }
}

extension CoreNFCChipReader: NFCTagReaderSessionDelegate {

    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    /// `nonisolated` plus `assumeIsolated`: das Protokoll verlangt keine
    /// Faden-Zusage, die Sitzung ist aber mit `queue: .main` angelegt. Damit steht
    /// hier hin, was tatsaechlich gilt, statt die Pruefung abzuschalten.
    nonisolated func tagReaderSession(
        _ session: NFCTagReaderSession,
        didInvalidateWithError error: Error
    ) {
        MainActor.assumeIsolated { handleInvalidation(error) }
    }

    private func handleInvalidation(_ error: Error) {
        self.session = nil
        // Ein Abbruch durch den Benutzer ist kein Fehler, den man ihm melden muss -
        // er weiss, dass er abgebrochen hat.
        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            finish(.failure(ReadError(.connectionLost, "vom Benutzer beendet")))
            return
        }
        finish(.failure(CoreNFCChipReader.classify(error)))
    }

    nonisolated func tagReaderSession(
        _ session: NFCTagReaderSession,
        didDetect tags: [NFCTag]
    ) {
        MainActor.assumeIsolated { handleDetection(session: session, tags: tags) }
    }

    private func handleDetection(session: NFCTagReaderSession, tags: [NFCTag]) {
        guard let pending else {
            session.invalidate()
            return
        }
        guard tags.count == 1, case let .iso7816(tag) = tags[0] else {
            session.invalidate(errorMessage: strings[.errorUnsupportedTag])
            finish(.failure(ReadError(.unsupportedTag, "kein ISO7816-Tag")))
            return
        }

        Task {
            do {
                pending.onProgress(.connecting)
                try await session.connect(to: tags[0])

                let data = try await self.readDocument(
                    from: tag,
                    key: pending.key,
                    readPhoto: pending.readPhoto,
                    onProgress: pending.onProgress
                )
                session.alertMessage = self.strings[.actionDone]
                session.invalidate()
                self.finish(.success(data))
            } catch {
                let mapped = error as? ReadError ?? CoreNFCChipReader.classify(error)
                session.invalidate(errorMessage: self.strings[mapped.kind.messageKey])
                self.finish(.failure(mapped))
            }
        }
    }

    // -----------------------------------------------------------------------
    // Der Ablauf
    // -----------------------------------------------------------------------

    private func readDocument(
        from tag: NFCISO7816Tag,
        key: AccessKey,
        readPhoto: Bool,
        onProgress: @escaping (ReadStep) -> Void
    ) async throws -> DocumentData {
        onProgress(.authenticating)

        // EF.CardAccess **vor** der Auswahl des eMRTD-Applets: danach ist die
        // Datei nicht mehr zu erreichen. Gelesen wird ueber die Kurzkennung, ohne
        // vorheriges SELECT - das ist der Weg, den ICAO 9303 Teil 10 dafuer
        // vorsieht, und er kommt ohne einen Aufruf aus, der schiefgehen kann.
        let cardAccess = try await readBinary(from: tag, shortFileId: 0x1C)

        guard let info = try PaceInfo.first(inCardAccess: cardAccess) else {
            // Fuer eine CIE ist ein fehlender PACEInfo ein Fehler; ein Pass ohne
            // PACE ist ein BAC-Pass und keine Stoerung. Die Unterscheidung
            // entscheidet der Schluesseltyp - genau wie in der Android-Fassung.
            throw ReadError(
                key.isCan ? .noPaceSupport : .paceUnavailable,
                "EF.CardAccess enthaelt keinen PACEInfo"
            )
        }

        let channel = try await pace.establish(info: info, key: key) { apdu in
            try await self.transceive(tag: tag, apdu: apdu)
        }

        // Ab hier laeuft alles ueber den gesicherten Kanal. Der Rest des Ablaufs -
        // DG1, DG11, DG12, DG2, DG14, EF.SOD, Passive Authentication - kommt mit
        // dem PACE-Backend; siehe docs/NFC-PACE.md, Abschnitt „Was danach noch
        // fehlt". Bis dahin ist diese Stelle nicht erreichbar, weil
        // `establish` vorher wirft.
        _ = channel
        throw ReadError(.paceUnavailable, "Datengruppen-Leser fehlt")
    }

    /// READ BINARY mit Kurzkennung, in Bloecken.
    private func readBinary(from tag: NFCISO7816Tag, shortFileId: UInt8) async throws -> [UInt8] {
        var out: [UInt8] = []
        var offset = 0
        let blockSize = 0xE0

        while true {
            // Erster Aufruf: P1 traegt die Kurzkennung (0x80 | SFI), P2 den
            // Versatz. Danach ist die Datei ausgewaehlt und P1/P2 sind der reine
            // Versatz.
            let p1: UInt8
            let p2: UInt8
            if offset == 0 {
                p1 = 0x80 | shortFileId
                p2 = 0
            } else {
                p1 = UInt8((offset >> 8) & 0x7F)
                p2 = UInt8(offset & 0xFF)
            }

            let apdu = NFCISO7816APDU(
                instructionClass: 0x00,
                instructionCode: 0xB0,
                p1Parameter: p1,
                p2Parameter: p2,
                data: Data(),
                expectedResponseLength: blockSize
            )
            let (data, sw1, sw2) = try await tag.sendCommand(apdu: apdu)
            let status = UInt16(sw1) << 8 | UInt16(sw2)

            // 0x6B00 heisst „hinter dem Ende gelesen" - bei einer Datei, deren
            // Laenge man nicht vorher kennt, ist das das normale Ende.
            if status == 0x6B00 || (status == 0x6282 && !data.isEmpty) { break }
            guard status == 0x9000 else {
                if out.isEmpty { throw ReadError(.noPaceSupport, "READ BINARY \(String(status, radix: 16))") }
                break
            }

            out.append(contentsOf: data)
            if data.count < blockSize { break }
            offset += data.count
        }

        guard !out.isEmpty else {
            throw ReadError(.noPaceSupport, "EF.CardAccess leer")
        }
        return out
    }

    private func transceive(tag: NFCISO7816Tag, apdu: [UInt8]) async throws -> [UInt8] {
        guard let command = NFCISO7816APDU(data: Data(apdu)) else {
            throw ReadError(.unknown, "APDU nicht baubar")
        }
        let (data, sw1, sw2) = try await tag.sendCommand(apdu: command)
        return Array(data) + [sw1, sw2]
    }

    /// Ordnet einen beliebigen Fehler einer ``ReadErrorKind`` zu.
    ///
    /// Reihenfolge wie in der Android-Fassung: eine abgerissene Verbindung
    /// schlaegt alles.
    private static func classify(_ error: Error) -> ReadError {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerTransceiveErrorTagConnectionLost,
                 .readerTransceiveErrorTagResponseError,
                 .readerTransceiveErrorSessionInvalidated,
                 .readerSessionInvalidationErrorSessionTimeout:
                return ReadError(.connectionLost, "\(readerError.code.rawValue)")
            default:
                return ReadError(.unknown, "\(readerError.code.rawValue)")
            }
        }
        return ReadError(.unknown, "\(type(of: error))")
    }
}

extension AccessKey {
    var isCan: Bool {
        if case .can = self { return true }
        return false
    }
}
