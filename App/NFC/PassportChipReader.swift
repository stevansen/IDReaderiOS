import CoreNFC
import Foundation
import IDReaderCore
import NFCPassportReaderCAN

/// Liest CIE und ePass ueber die gepatchte Fassung von NFCPassportReader.
///
/// ## Wo die Grenze verlaeuft
///
/// Diese Klasse rechnet nichts. Sie uebergibt den Schluessel, uebersetzt den
/// Fortschritt in die vier Phasen des Lesescreens und bildet danach das Ergebnis
/// auf ``DocumentData`` ab. Alles Kryptografische - PACE ueber brainpoolP256r1,
/// Secure Messaging, Passive Authentication, Chip-Authentisierung - liegt in der
/// Bibliothek unter `ThirdParty/`, samt der beiden Zeilen, die dort fuer die CAN
/// zu aendern waren. Warum das nicht selbst geschrieben ist, steht in
/// docs/NFC-PACE.md; die Kurzform: handgeschriebene Kryptografie in einer App,
/// die Ausweise liest, ist kein Sparen.
///
/// ## Was die Abbildung entscheidet
///
/// Die Bibliothek liefert vier voneinander unabhaengige Wahrheiten -
/// „Datengruppen unveraendert", „Signatur gueltig", „Kette bis zu einer
/// hinterlegten Stelle", „Chip hat sich ausgewiesen". Daraus ein einzelnes Urteil
/// zu machen, ist die eigentliche Arbeit hier, und sie folgt Zeile fuer Zeile der
/// Android-Fassung: **alle** muessen aufgehen, sonst ist es kein Ja. Siehe
/// ``authenticity(from:)``.
@MainActor
final class PassportChipReader: ChipDocumentReader {

    private let strings: Strings
    private let trustBundle: URL?
    private var reader: PassportReader?

    init(strings: Strings, trustBundle: URL? = CscaTrustStore.bundleURL()) {
        self.strings = strings
        self.trustBundle = trustBundle
    }

    var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    func read(
        key: AccessKey,
        readPhoto: Bool,
        onProgress: @escaping (ReadStep) -> Void
    ) async throws -> ChipReadResult {
        let reader = PassportReader()
        self.reader = reader
        defer { self.reader = nil }

        onProgress(.waitingForCard)

        // Welche Datengruppen gelesen werden.
        //
        // Ausdruecklich aufgezaehlt und nicht „alle": DG2 ist mit Abstand die
        // groesste und soll abwaehlbar bleiben, DG3 (Fingerabdruecke) wird nie
        // verlangt - sie braucht ein Inspektionssystem-Zertifikat, die App hat
        // keines und fragt nach keinem. DG12 ist klein und schnell gelesen,
        // deshalb auch im schnellen Weg dabei.
        var tags: [DataGroupId] = [.COM, .SOD, .DG1, .DG11, .DG12, .DG14]
        if readPhoto { tags.append(.DG2) }

        let model: NFCPassportModel
        do {
            model = try await reader.readPassport(
                accessKey: key.libraryKey,
                tags: tags,
                skipSecureElements: true,
                customDisplayMessage: { message in
                    // Der Rueckruf kommt, um den Text im Systemblatt zu setzen -
                    // und er ist der einzige Fortschrittsbericht, den die
                    // Bibliothek hergibt. Also wird er beides: `nil` heisst „nimm
                    // deinen eigenen Text", und der Schritt wandert nach draussen.
                    onProgress(PassportChipReader.step(for: message))
                    return nil
                }
            )
        } catch NFCPassportReaderError.UserCanceled {
            // Das Systemblatt hat einen eigenen „Abbrechen"-Knopf, und solange es
            // oben ist, ist der eigene nicht erreichbar. Wer ihn drueckt, will
            // zurueck zur Maske - nicht eine Fehlermeldung mit „Erneut
            // versuchen".
            throw ReadCancelled()
        } catch {
            throw PassportChipReader.mapError(error, key: key)
        }

        onProgress(.verifying)
        // Die Pruefung laeuft ausdruecklich gegen das mitgelieferte Buendel und
        // nicht gegen eine Adresse im Netz. Fehlt das Buendel, wird gelesen, aber
        // nicht geprueft - und das Ergebnis sagt das dann auch.
        model.verifyPassport(masterListURL: trustBundle)

        onProgress(.done)
        return ChipReadResult(
            data: documentData(from: model),
            signer: PassportChipReader.signer(from: model)
        )
    }

    func abort() {
        // Die Bibliothek beendet ihre Sitzung selbst, sobald der Vorgang endet
        // oder der Benutzer das Systemblatt schliesst. Ein eigener Abbruch von
        // hier aus hat keinen Angriffspunkt - und die laufende Aufgabe wird vom
        // Modell ohnehin abgebrochen.
        reader = nil
    }

    // -----------------------------------------------------------------------
    // Fortschritt
    // -----------------------------------------------------------------------

    private static func step(for message: NFCViewDisplayMessage) -> ReadStep {
        switch message {
        case .requestPresentPassport: .waitingForCard
        case .authenticatingWithPassport: .authenticating
        case let .readingDataGroupProgress(group, _): step(for: group)
        case .activeAuthentication: .verifying
        case .successfulRead: .done
        case .error: .verifying
        }
    }

    private static func step(for group: DataGroupId) -> ReadStep {
        switch group {
        case .DG1: .readingDG1
        case .DG2: .readingDG2
        case .SOD, .COM: .readingSOD
        default: .readingDG11
        }
    }

    // -----------------------------------------------------------------------
    // Fehler
    // -----------------------------------------------------------------------

    /// Ordnet einen Fehler der Bibliothek einer ``ReadErrorKind`` zu.
    ///
    /// Reihenfolge wie in der Android-Fassung: eine abgerissene Verbindung
    /// schlaegt alles. Und die Meldung fuer einen falschen Schluessel haengt an
    /// der Schluesselart - bei der CAN ist **eine** Zahl zu pruefen, beim Pass
    /// sind es drei Felder samt Pruefziffern, und das ist ein anderer Satz.
    private static func mapError(_ error: Error, key: AccessKey) -> ReadError {
        guard let libraryError = error as? NFCPassportReaderError else {
            return ReadError(.unknown, "\(type(of: error))")
        }

        switch libraryError {
        case .ConnectionError, .TimeOutError, .NoConnectedTag:
            return ReadError(.connectionLost, "\(libraryError)")
        case .UserCanceled:
            // Wird in `read` vorher abgefangen; hier nur der Vollstaendigkeit
            // halber, damit der Schalter nichts verschluckt.
            return ReadError(.connectionLost, "vom Benutzer beendet")
        case .TagNotValid, .MoreThanOneTagFound:
            return ReadError(.unsupportedTag, "\(libraryError)")
        case .NFCNotSupported:
            return ReadError(.unsupportedTag, "kein NFC")
        case .NotYetSupported:
            // Die Bibliothek meldet so unter anderem „PACE not supported", also
            // eine Karte ohne PACEInfo in EF.CardAccess. Eine CIE 3.0 ist das dann
            // nicht.
            return ReadError(.noPaceSupport, "\(libraryError)")
        case .PACEError, .InvalidMRZKey, .InvalidDataPassed:
            // Steht die Karte noch, ist praktisch immer der Schluessel falsch.
            return ReadError(key.isCan ? .wrongCan : .wrongMrzKey, "\(libraryError)")
        case let .ResponseError(_, sw1, sw2):
            // 0x6982 „security status not satisfied" ist die Antwort des Chips auf
            // einen falschen Schluessel.
            let status = UInt16(sw1) << 8 | UInt16(sw2)
            if status == 0x6982 || status == 0x6983 {
                return ReadError(key.isCan ? .wrongCan : .wrongMrzKey, "SW \(String(status, radix: 16))")
            }
            return ReadError(.unknown, "SW \(String(status, radix: 16))")
        default:
            return ReadError(.unknown, "\(libraryError)")
        }
    }

    // -----------------------------------------------------------------------
    // Abbildung auf DocumentData
    // -----------------------------------------------------------------------

    private func documentData(from model: NFCPassportModel) -> DocumentData {
        let dg11 = model.getDataGroup(.DG11) as? DataGroup11
        let dg12 = model.getDataGroup(.DG12) as? DataGroup12

        // Geburtsdatum bevorzugt aus DG11 - dort steht ein vierstelliges Jahr und
        // es braucht keine Schaetzung des Jahrhunderts.
        let birth = PassportChipReader.fullDate(dg11?.dateOfBirth)
            ?? PassportChipReader.mrzDate(model.dateOfBirth, isExpiry: false)

        return DocumentData(
            provenance: .chip,
            surname: PassportChipReader.clean(model.lastName),
            givenNames: PassportChipReader.clean(model.firstName),
            dateOfBirth: birth,
            gender: PassportChipReader.gender(model.gender),
            nationality: PassportChipReader.clean(model.nationality),
            issuingState: PassportChipReader.cleanOrNil(model.issuingAuthority),
            documentNumber: PassportChipReader.clean(model.documentNumber),
            // Der Rohwert von der Karte und nicht der schon zugeordnete Typ:
            // aendert sich die Zuordnung spaeter, ordnen auch gespeicherte
            // Datensaetze noch richtig zu.
            documentCode: PassportChipReader.cleanOrNil(model.documentType),
            dateOfExpiry: PassportChipReader.mrzDate(model.documentExpiryDate, isExpiry: true),
            placeOfBirth: PassportChipReader.cleanOrNil(dg11?.placeOfBirth ?? model.placeOfBirth),
            residence: PassportChipReader.cleanOrNil(dg11?.address ?? model.residenceAddress),
            codiceFiscale: PassportChipReader.codiceFiscale(dg11?.personalNumber ?? model.personalNumber),
            issuingAuthority: PassportChipReader.cleanOrNil(dg12?.issuingAuthority),
            dateOfIssue: PassportChipReader.fullDate(dg12?.dateOfIssue),
            otherNames: PassportChipReader.cleanOrNil(dg12?.otherPersonsDetails),
            profession: PassportChipReader.cleanOrNil(dg11?.profession),
            title: PassportChipReader.cleanOrNil(dg11?.title),
            personalSummary: PassportChipReader.cleanOrNil(dg11?.personalSummary),
            telephone: PassportChipReader.cleanOrNil(dg11?.telephone ?? model.phoneNumber),
            otherValidDocuments: PassportChipReader.cleanOrNil(dg11?.tdNumbers),
            custodyInformation: PassportChipReader.cleanOrNil(dg11?.custodyInfo),
            endorsements: PassportChipReader.cleanOrNil(dg12?.endorsementsOrObservations),
            taxOrExitRequirements: PassportChipReader.cleanOrNil(dg12?.taxOrExitRequirements),
            // Klassen gibt es nur auf der Fahrerlaubnis.
            categories: nil,
            photo: photo(from: model),
            authenticity: PassportChipReader.authenticity(from: model)
        )
    }

    /// Das Lichtbild aus DG2.
    ///
    /// Bewusst nicht `model.passportImage`: das ruft `UIImage(data:)`, und iOS
    /// decodiert kein JPEG 2000 - bei einer CIE kaeme dort immer nil heraus, ohne
    /// dass sich sagen liesse, warum. Die rohen Bytes gehen deshalb an
    /// ``FaceImageDecoder``, der das Format an den Magic Bytes erkennt und es
    /// weitergibt, wenn er es nicht lesen kann.
    private func photo(from model: NFCPassportModel) -> DocumentPhoto? {
        guard let dg2 = model.getDataGroup(.DG2) as? DataGroup2, !dg2.imageData.isEmpty else {
            return nil
        }
        return FaceImageDecoder.decode(Data(dg2.imageData), declaredMimeType: nil)
    }

    /// Das Urteil, aus vier voneinander unabhaengigen Teilpruefungen.
    ///
    /// Alle muessen aufgehen. Die dritte - Kette bis zu einer hinterlegten
    /// italienischen CSCA - ist die, auf die es ankommt: ohne sie koennte jemand
    /// eine Karte mit selbst erzeugtem Schluesselpaar bespielen, und die ersten
    /// zwei waeren trotzdem gruen.
    ///
    /// Ob die Karte eine Chip-Authentisierung ueberhaupt anbietet, kommt aus dem
    /// **signierten** Security Object - `isChipAuthenticationSupported` liest die
    /// SecurityInfos aus DG14, dessen Hash gegen das SOD geprueft wird. Wer
    /// stattdessen fragt, ob DG14 lesbar war, laesst eine Kopie durch, die DG14
    /// einfach weglaesst.
    /// Der Dokumentsignierer, so wie die Sperrpruefung ihn braucht.
    ///
    /// ## Warum das Zertifikat noch einmal gelesen wird
    ///
    /// Die Bibliothek hat `getSerialNumber()`, und die ist hier unbrauchbar: sie
    /// laeuft ueber `ASN1_INTEGER_get`, das eine `long` zurueckgibt. Eine
    /// Seriennummer eines Dokumentsignierers ist bis zu zwanzig Byte lang - dabei
    /// kommt -1 heraus, und eine Sperrliste gegen -1 abzugleichen ist keine
    /// Pruefung, sondern eine, die immer „nicht gesperrt" sagt.
    ///
    /// Also wird das Zertifikat als PEM abgeholt - die einzige vollstaendige
    /// Ausgabe, die die Bibliothek hergibt - und im Paket selbst gelesen. Kein
    /// weiterer Eingriff in fremden Code.
    static func signer(from model: NFCPassportModel) -> SignerReference? {
        guard let certificate = model.documentSigningCertificate else { return nil }
        // Kein Fehlerfall, der jemanden aufhalten sollte: ohne lesbares
        // Zertifikat entfaellt die Sperrpruefung fuer diesen Datensatz, und die
        // Oberflaeche sagt das dann auch.
        guard let identity = try? CertificateReader.identity(
            ofPEM: certificate.certToPEM()
        ) else { return nil }
        return SignerReference(identity)
    }

    static func authenticity(from model: NFCPassportModel) -> Authenticity {
        let hashes = model.dataGroupHashes
        let checked = hashes.keys.compactMap(number(of:)).sorted()
        let mismatched = hashes
            .filter { !$0.value.match }
            .keys
            .compactMap(number(of:))
            .sorted()

        let dataGroupsIntact = !hashes.isEmpty && mismatched.isEmpty
        let signatureValid = model.passportCorrectlySigned
        let chainTrusted = model.documentSigningCertificateVerified
        let chipExpected = model.isChipAuthenticationSupported
        let chipAuthenticated = model.chipAuthenticationStatus == .success

        let signer = model.documentSigningCertificate?.getSubjectName()
        let anchor = model.countrySigningCertificate?.getSubjectName()

        // Ohne Security Object gibt es nichts zu pruefen - das ist etwas anderes
        // als eine fehlgeschlagene Pruefung, und es muss auch anders heissen.
        if hashes.isEmpty && !signatureValid {
            return Authenticity.notChecked(.sodUnavailable)
        }

        let status: AuthenticityStatus
        var failure: AuthenticityFailure?

        if !dataGroupsIntact {
            status = .failed
            failure = .dataGroupMismatch
        } else if !signatureValid {
            status = .failed
            failure = .signatureInvalid
        } else if !chainTrusted {
            status = .failed
            // Kein hinterlegter Anker gefunden, oder die Kette ging nicht auf. Die
            // Bibliothek unterscheidet das nicht, und einen der beiden Gruende zu
            // erfinden waere schlechter als den allgemeineren zu nennen.
            failure = .noTrustAnchor
        } else if chipExpected && !chipAuthenticated {
            // Die Daten sind echt. Nur der Chip hat nicht nachgewiesen, dass er
            // das Original ist - genau so verhaelt sich eine Kopie, auf die die
            // Datengruppen eines echten Ausweises geschrieben wurden.
            status = .failed
            failure = .chipNotAuthentic
        } else {
            status = .verified
        }

        return Authenticity(
            status: status,
            dataGroupsIntact: dataGroupsIntact,
            signatureValid: signatureValid,
            chainTrusted: chainTrusted,
            chipAuthenticationExpected: chipExpected,
            chipAuthenticated: chipAuthenticated,
            checkedDataGroups: checked,
            mismatchedDataGroups: mismatched,
            signerName: signer,
            trustAnchorName: anchor,
            digestAlgorithm: model.sodHashAlgorithm,
            failure: failure
        )
    }

    private static func number(of group: DataGroupId) -> Int? {
        // Der Name traegt die Nummer; `DataGroupId` gibt sie nicht anders heraus.
        let name = "\(group)"
        guard name.hasPrefix("DG"), let value = Int(name.dropFirst(2)) else { return nil }
        return value
    }

    // -----------------------------------------------------------------------
    // Felder aufraeumen
    // -----------------------------------------------------------------------

    /// Entfernt MRZ-Fuellzeichen und ueberzaehlige Leerzeichen.
    static func clean(_ raw: String?) -> String {
        let replaced = (raw ?? "").replacingOccurrences(of: "<", with: " ")
        let collapsed = replaced.split(separator: " ", omittingEmptySubsequences: true)
        return collapsed.joined(separator: " ")
    }

    static func cleanOrNil(_ raw: String?) -> String? {
        // „?" ist die Antwort der Bibliothek fuer ein Feld, das die Karte nicht
        // fuehrt. Als Wert weitergegeben stuende es im Einsatzbericht.
        guard let raw, raw != "?" else { return nil }
        let cleaned = clean(raw)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Pruefform des Codice Fiscale: 16 Zeichen, Buchstaben und Ziffern.
    ///
    /// Der Grund fuer die Pruefung ist ein Fehler, der ohne Paesse nie aufgefallen
    /// waere. Das ICAO-Feld, aus dem der Wert stammt, ist kein
    /// Steuernummernfeld, sondern „personal number or other optional data" - was
    /// darin steht, entscheidet der ausstellende Staat.
    ///
    /// Schlimmer als die falsche Beschriftung ist die Folge: dieser Wert ist der
    /// Personenschluessel des Archivs. Zwei verschiedene Paesse mit demselben
    /// Fuellwert wuerden zu einer Person verschmelzen.
    static func codiceFiscale(_ raw: String?) -> String? {
        guard let value = cleanOrNil(raw)?.uppercased() else { return nil }
        guard value.count == 16, value.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return nil
        }
        return value
    }

    /// DG11 und DG12 liefern Datumsangaben als JJJJMMTT.
    static func fullDate(_ raw: String?) -> String? {
        let digits = (raw ?? "").filter(\.isNumber)
        guard digits.count == 8 else { return nil }
        let c = Array(digits)
        return "\(String(c[6..<8])).\(String(c[4..<6])).\(String(c[0..<4]))"
    }

    /// MRZ-Datum JJMMTT -> TT.MM.JJJJ.
    ///
    /// Ablaufdaten liegen immer in der Zukunft. Bei Geburtsdaten wird das
    /// Jahrhundert ueber das aktuelle Jahr geschaetzt: ein zweistelliges Jahr
    /// groesser als das aktuelle gehoert ins 20. Jahrhundert.
    static func mrzDate(_ raw: String?, isExpiry: Bool) -> String {
        let value = (raw ?? "").filter(\.isNumber)
        guard value.count == 6 else { return raw ?? "" }
        let c = Array(value)
        guard let twoDigitYear = Int(String(c[0..<2])) else { return value }

        let year: Int
        if isExpiry {
            year = 2000 + twoDigitYear
        } else {
            let current = Calendar.current.component(.year, from: Date()) % 100
            year = twoDigitYear > current ? 1900 + twoDigitYear : 2000 + twoDigitYear
        }
        return "\(String(c[4..<6])).\(String(c[2..<4])).\(year)"
    }

    static func gender(_ raw: String?) -> Gender {
        switch (raw ?? "").uppercased() {
        case "M", "MALE": .male
        case "F", "FEMALE": .female
        default: .unknown
        }
    }
}

private extension AccessKey {

    var isCan: Bool {
        if case .can = self { return true }
        return false
    }

    /// Der Schluessel in der Form, die die Bibliothek erwartet.
    ///
    /// Beim Pass ist das die zusammengesetzte MRZ-Information **mit** den drei
    /// Pruefziffern - die Bibliothek rechnet sie nicht selbst aus, anders als
    /// JMRTD auf der Android-Seite. Deshalb steht die Berechnung hier.
    var libraryKey: PassportReader.AccessKey {
        switch self {
        case let .can(can):
            return .can(can)
        case let .mrz(number, birth, expiry):
            let padded = number.count >= 9
                ? String(number.prefix(9))
                : number + String(repeating: "<", count: 9 - number.count)
            // Die Pruefziffern gehoeren mit hinein. Anders als JMRTD auf der
            // Android-Seite rechnet diese Bibliothek sie nicht selbst aus - wer
            // sie weglaesst, bildet einen falschen Schluessel, und der Chip sagt
            // dazu nur nein.
            let key = padded + (MrzScan.checkDigit(padded) ?? "0")
                + birth + (MrzScan.checkDigit(birth) ?? "0")
                + expiry + (MrzScan.checkDigit(expiry) ?? "0")
            return .mrz(key)
        }
    }
}
