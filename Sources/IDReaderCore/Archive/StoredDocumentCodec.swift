import Foundation

/// Wandelt Datensaetze in JSON und zurueck.
///
/// Eigenhaendig statt mit `Codable`, damit das Format sichtbar bleibt - und weil
/// es **dasselbe** Format ist wie im Android-Original, Feldname fuer Feldname.
/// Wer ein Archiv von dort entschluesselt bekommt, kann es hier lesen; das war
/// beim Portieren die einzige Stelle, an der sich das ohne Aufwand einrichten
/// liess, und es ist die Stelle, an der es am meisten wert ist.
///
/// Beim Lesen wird jeder Datensatz einzeln abgesichert: ein beschaedigter Eintrag
/// soll nicht das ganze Archiv unlesbar machen, sondern nur selbst wegfallen.
public enum StoredDocumentCodec {

    /// 6 seit der Aufnahme von `documentCode`.
    /// 7 seit der Aufnahme des ausstellenden Staates und der uebrigen
    /// Textangaben aus DG11 und DG12.
    /// 8 seit der Herkunft des Datensatzes und den Fahrerlaubnisklassen.
    ///
    /// Bei 8 waere ein optionales Feld sogar gefaehrlich gewesen: ein alter
    /// Datensatz ohne Herkunft muesste als Chip-Lesung gelten, und genau das ist
    /// die Aussage, die nicht geraten werden darf.
    ///
    /// 9 seit dem Durchgang zur Datenminimierung: Wohnsitz, Steuernummer, Beruf
    /// und Telefon werden nicht mehr aufbewahrt, dafuer stehen der Abdruck des
    /// Personenschluessels und die Liste der weggelassenen Felder darin.
    ///
    /// **Diese Erhoehung kostet die Deckungsgleichheit mit dem Android-Format**,
    /// und das ist der Preis, der es wert war: ein Archiv, das eine Steuernummer
    /// nicht enthaelt, kann sie auch nicht verlieren. Die Android-Fassung sollte
    /// dieselbe Aenderung bekommen; bis dahin sind die Formate 8 und 9 nicht
    /// gegenseitig lesbar.
    ///
    /// Eine Erhoehung verwirft das vorhandene Archiv - siehe ``decodeAll(_:)``.
    /// Das ist bewusst in Kauf genommen: ein Feld nachtraeglich als optional zu
    /// lesen waere moeglich, wuerde aber bedeuten, dass gespeicherte Scans
    /// dauerhaft ohne es dastehen.
    public static let version = 9

    public static func encodeAll(_ documents: [StoredDocument]) throws -> Data {
        let root: [String: Any] = [
            "version": version,
            "records": documents.map(encode),
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [])
    }

    /// - Parameter log: Diagnose fuer den Aufrufer - nie Inhalte, nur
    ///   Fehlerarten. Als Parameter und nicht als globale Ablage: eine
    ///   veraenderliche statische Eigenschaft waere geteilter Zustand, und den
    ///   verbietet Swift 6 zu Recht.
    public static func decodeAll(
        _ data: Data,
        log: ((String) -> Void)? = nil
    ) -> [StoredDocument] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log?("Archiv nicht lesbar: kein JSON-Objekt")
            return []
        }

        let stored = root["version"] as? Int ?? 0
        guard stored == version else {
            // Ein Formatwechsel verwirft das Archiv - migrieren laesst sich ein
            // unbekanntes Format nicht. Das darf aber nicht unbemerkt passieren,
            // sonst sucht man den Fehler an der falschen Stelle.
            log?("Archivformat \(stored) passt nicht zu \(version) - verworfen")
            return []
        }

        guard let records = root["records"] as? [Any] else { return [] }
        let decoded = records.compactMap { ($0 as? [String: Any]).flatMap { decode($0, log: log) } }
        if decoded.count != records.count {
            log?("\(records.count - decoded.count) von \(records.count) Eintraegen unlesbar")
        }
        return decoded
    }

    // -----------------------------------------------------------------------
    // Einzelner Datensatz
    // -----------------------------------------------------------------------

    private static func encode(_ document: StoredDocument) -> [String: Any] {
        let d = document.data
        var data: [String: Any] = [
            "surname": d.surname,
            "givenNames": d.givenNames,
            "dateOfBirth": d.dateOfBirth,
            "gender": d.gender.rawValue,
            "provenance": d.provenance.rawValue,
            "nationality": d.nationality,
            "documentNumber": d.documentNumber,
            "dateOfExpiry": d.dateOfExpiry,
            "authenticity": encode(d.authenticity),
        ]
        // Optionales einzeln, damit ein fehlender Wert als JSON-null erscheint und
        // nicht als leere Zeichenkette. Der Unterschied ist die Aussage "steht
        // nicht im Dokument" gegen "wurde als leer gelesen".
        // Wohnsitz, Steuernummer, Beruf und Telefon stehen hier mit Absicht
        // nicht: sie werden angezeigt und nicht aufbewahrt. Was davon dagewesen
        // ist, sagt `droppedFields`.
        let optionals: [String: String?] = [
            "issuingState": d.issuingState,
            "documentCode": d.documentCode,
            "placeOfBirth": d.placeOfBirth,
            "issuingAuthority": d.issuingAuthority,
            "dateOfIssue": d.dateOfIssue,
            "otherNames": d.otherNames,
            "title": d.title,
            "personalSummary": d.personalSummary,
            "otherValidDocuments": d.otherValidDocuments,
            "custodyInformation": d.custodyInformation,
            "endorsements": d.endorsements,
            "taxOrExitRequirements": d.taxOrExitRequirements,
            "categories": d.categories,
        ]
        for (key, value) in optionals {
            data[key] = value ?? NSNull()
        }
        data["photo"] = encode(d.photo)
        data["droppedFields"] = d.droppedFields.map(\.rawValue)

        return [
            "storedAt": document.storedAt,
            "cardId": document.cardId ?? NSNull(),
            "can": document.can,
            "identityDigest": document.identityDigest ?? NSNull(),
            "data": data,
        ]
    }

    private static func decode(
        _ record: [String: Any],
        log: ((String) -> Void)?
    ) -> StoredDocument? {
        guard let storedAt = (record["storedAt"] as? NSNumber)?.int64Value,
              let raw = record["data"] as? [String: Any],
              let provenance = (raw["provenance"] as? String).flatMap(RecordProvenance.init(rawValue:)),
              let surname = raw["surname"] as? String,
              let givenNames = raw["givenNames"] as? String,
              let dateOfBirth = raw["dateOfBirth"] as? String,
              let gender = (raw["gender"] as? String).flatMap(Gender.init(rawValue:)),
              let nationality = raw["nationality"] as? String,
              let documentNumber = raw["documentNumber"] as? String,
              let dateOfExpiry = raw["dateOfExpiry"] as? String,
              let authenticityRaw = raw["authenticity"] as? [String: Any]
        else {
            log?("Eintrag unlesbar: Pflichtfeld fehlt oder hat den falschen Typ")
            return nil
        }

        let data = DocumentData(
            provenance: provenance,
            surname: surname,
            givenNames: givenNames,
            dateOfBirth: dateOfBirth,
            gender: gender,
            nationality: nationality,
            issuingState: string(raw, "issuingState"),
            documentNumber: documentNumber,
            documentCode: string(raw, "documentCode"),
            dateOfExpiry: dateOfExpiry,
            placeOfBirth: string(raw, "placeOfBirth"),
            issuingAuthority: string(raw, "issuingAuthority"),
            dateOfIssue: string(raw, "dateOfIssue"),
            otherNames: string(raw, "otherNames"),
            title: string(raw, "title"),
            personalSummary: string(raw, "personalSummary"),
            otherValidDocuments: string(raw, "otherValidDocuments"),
            custodyInformation: string(raw, "custodyInformation"),
            endorsements: string(raw, "endorsements"),
            taxOrExitRequirements: string(raw, "taxOrExitRequirements"),
            categories: string(raw, "categories"),
            photo: (raw["photo"] as? [String: Any]).flatMap(decodePhoto),
            authenticity: decodeAuthenticity(authenticityRaw),
            droppedFields: (raw["droppedFields"] as? [Any])?
                .compactMap { ($0 as? String).flatMap(MinimisedField.init(rawValue:)) } ?? []
        )

        return StoredDocument(
            data: data,
            storedAt: storedAt,
            cardId: string(record, "cardId"),
            can: string(record, "can") ?? "",
            identityDigest: string(record, "identityDigest")
        )
    }

    // -----------------------------------------------------------------------
    // Lichtbild
    // -----------------------------------------------------------------------

    /// Das Lichtbild liegt als JPEG in der Ablage, nicht als die urspruenglichen
    /// JPEG-2000-Bytes: die sind nach dem Decodieren nicht mehr vorhanden, und ein
    /// zweites Mal JPEG 2000 zu schreiben braeuchte einen Encoder ohne Nutzen fuer
    /// die Anzeige.
    private static func encode(_ photo: DocumentPhoto?) -> Any {
        guard let photo, let jpeg = photo.jpegData else { return NSNull() }
        return [
            "originalMimeType": photo.mimeType,
            "sizeBytes": photo.sizeBytes,
            "jpeg": jpeg.base64EncodedString(),
        ]
    }

    private static func decodePhoto(_ raw: [String: Any]) -> DocumentPhoto? {
        guard let encoded = raw["jpeg"] as? String,
              let bytes = Data(base64Encoded: encoded)
        else { return nil }
        return DocumentPhoto(
            jpegData: bytes,
            mimeType: raw["originalMimeType"] as? String ?? "image/jpeg",
            sizeBytes: (raw["sizeBytes"] as? NSNumber)?.intValue ?? bytes.count
        )
    }

    // -----------------------------------------------------------------------
    // Echtheitspruefung
    // -----------------------------------------------------------------------

    private static func encode(_ authenticity: Authenticity) -> [String: Any] {
        [
            "status": authenticity.status.rawValue,
            "dataGroupsIntact": authenticity.dataGroupsIntact,
            "signatureValid": authenticity.signatureValid,
            "chainTrusted": authenticity.chainTrusted,
            "chipAuthenticationExpected": authenticity.chipAuthenticationExpected,
            "chipAuthenticated": authenticity.chipAuthenticated,
            "checkedDataGroups": authenticity.checkedDataGroups,
            "mismatchedDataGroups": authenticity.mismatchedDataGroups,
            "signerName": authenticity.signerName ?? NSNull(),
            "trustAnchorName": authenticity.trustAnchorName ?? NSNull(),
            "digestAlgorithm": authenticity.digestAlgorithm ?? NSNull(),
            "failure": authenticity.failure?.rawValue ?? NSNull(),
        ]
    }

    private static func decodeAuthenticity(_ raw: [String: Any]) -> Authenticity {
        Authenticity(
            status: (raw["status"] as? String).flatMap(AuthenticityStatus.init(rawValue:))
                ?? .notChecked,
            dataGroupsIntact: raw["dataGroupsIntact"] as? Bool ?? false,
            signatureValid: raw["signatureValid"] as? Bool ?? false,
            chainTrusted: raw["chainTrusted"] as? Bool ?? false,
            chipAuthenticationExpected: raw["chipAuthenticationExpected"] as? Bool ?? false,
            chipAuthenticated: raw["chipAuthenticated"] as? Bool ?? false,
            checkedDataGroups: (raw["checkedDataGroups"] as? [Any])?
                .compactMap { ($0 as? NSNumber)?.intValue } ?? [],
            mismatchedDataGroups: (raw["mismatchedDataGroups"] as? [Any])?
                .compactMap { ($0 as? NSNumber)?.intValue } ?? [],
            signerName: string(raw, "signerName"),
            trustAnchorName: string(raw, "trustAnchorName"),
            digestAlgorithm: string(raw, "digestAlgorithm"),
            failure: string(raw, "failure").flatMap(AuthenticityFailure.init(rawValue:))
        )
    }

    // -----------------------------------------------------------------------
    // Kleinigkeiten
    // -----------------------------------------------------------------------

    /// Wie `JSONObject.optStringOrNull` im Original: null bleibt null, und eine
    /// leere Zeichenkette gilt als nicht vorhanden.
    private static func string(_ raw: [String: Any], _ key: String) -> String? {
        guard let value = raw[key] as? String, !value.isEmpty else { return nil }
        return value
    }
}
