import Foundation

/// Lichtbild aus DG2.
///
/// ``jpegData`` ist nil, wenn die Karte ein Bildformat liefert, das die App
/// nicht decodieren kann. ``mimeType`` bleibt in dem Fall trotzdem gesetzt,
/// damit die Oberflaeche erklaeren kann, woran es lag.
///
/// Anders als beim Android-Original haelt der Datensatz **Bytes** und kein
/// decodiertes Bild: `UIImage` gibt es hier nicht (Core ist UI-frei), und in der
/// Ablage stand ohnehin schon JPEG. Das Decodieren gehoert damit an die einzige
/// Stelle, die es braucht - die Anzeige.
public struct DocumentPhoto: Sendable, Codable, Equatable {
    /// Bild als JPEG, nil wenn das Format nicht unterstuetzt wird.
    public var jpegData: Data?
    /// MIME-Typ laut DG2, z. B. "image/jp2" oder "image/jpeg".
    public var mimeType: String
    /// Groesse der Rohdaten in Byte - nur fuer die Diagnose.
    public var sizeBytes: Int

    public init(jpegData: Data?, mimeType: String, sizeBytes: Int) {
        self.jpegData = jpegData
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
    }
}

/// Ergebnis eines Lesevorgangs.
///
/// Alle Datumsfelder sind bereits als TT.MM.JJJJ formatiert. Felder aus DG11
/// sind optional, weil DG11 fehlen darf oder einzelne Tags nicht gesetzt sind.
///
/// Achtung: dieser Typ haelt Personendaten inklusive Lichtbild. Er wird nur im
/// verschluesselten Archiv abgelegt, nie geloggt und nur versendet, wenn der
/// Bediener es ausdruecklich veranlasst.
public struct DocumentData: Sendable, Codable, Equatable {
    /// Woher diese Angaben stammen. Die Unterscheidung ist wichtiger als jedes
    /// einzelne Feld hier.
    public var provenance: RecordProvenance

    public var surname: String
    public var givenNames: String
    /// Geburtsdatum, TT.MM.JJJJ.
    public var dateOfBirth: String
    public var gender: Gender
    /// Staatsangehoerigkeit als ISO-3166-Alpha-3-Code, z. B. "ITA".
    public var nationality: String

    /// Ausstellender Staat aus der MRZ, ebenfalls dreistellig.
    ///
    /// Nicht dasselbe wie die Staatsangehoerigkeit: ein Staat stellt Paesse auch
    /// fuer Staatenlose und in Sonderfaellen fuer Angehoerige anderer Staaten
    /// aus. Auf der Datenseite stehen beide getrennt, also stehen sie hier auch
    /// getrennt.
    public var issuingState: String?

    public var documentNumber: String

    /// Dokumentencode aus der MRZ nach ICAO 9303, z. B. "ID" oder "P".
    ///
    /// Bewusst der Rohwert von der Karte und nicht der schon zugeordnete Typ:
    /// aendert sich die Zuordnung spaeter, ordnen auch gespeicherte Datensaetze
    /// noch richtig zu.
    public var documentCode: String?

    /// Ablaufdatum, TT.MM.JJJJ.
    public var dateOfExpiry: String

    public var placeOfBirth: String?
    public var residence: String?
    /// Codice Fiscale (DG11 personal number, ersatzweise MRZ).
    public var codiceFiscale: String?
    /// Ausstellende Stelle (DG12).
    public var issuingAuthority: String?
    /// Ausstellungsdatum (DG12), TT.MM.JJJJ.
    public var dateOfIssue: String?

    // Die uebrigen Textangaben, die DG11 und DG12 fuehren koennen. Auf der CIE
    // ist davon fast nie etwas gesetzt, auf einem Pass kommt es vor. Aufgenommen,
    // weil ein Lesegeraet das Dokument vollstaendig wiedergeben soll, soweit es
    // Text ist - was ein Chip hergibt und die App verschweigt, fehlt spaeter im
    // Bericht und niemand weiss, dass es dagewesen waere.
    public var otherNames: String?
    public var profession: String?
    public var title: String?
    public var personalSummary: String?
    public var telephone: String?
    public var otherValidDocuments: String?
    public var custodyInformation: String?
    public var endorsements: String?
    public var taxOrExitRequirements: String?

    /// Fahrerlaubnisklassen, Feld 9 der Fahrerlaubnis. Bei Chip-Dokumenten leer.
    public var categories: String?

    public var photo: DocumentPhoto?
    public var authenticity: Authenticity

    public init(
        provenance: RecordProvenance,
        surname: String,
        givenNames: String,
        dateOfBirth: String,
        gender: Gender,
        nationality: String,
        issuingState: String? = nil,
        documentNumber: String,
        documentCode: String? = nil,
        dateOfExpiry: String,
        placeOfBirth: String? = nil,
        residence: String? = nil,
        codiceFiscale: String? = nil,
        issuingAuthority: String? = nil,
        dateOfIssue: String? = nil,
        otherNames: String? = nil,
        profession: String? = nil,
        title: String? = nil,
        personalSummary: String? = nil,
        telephone: String? = nil,
        otherValidDocuments: String? = nil,
        custodyInformation: String? = nil,
        endorsements: String? = nil,
        taxOrExitRequirements: String? = nil,
        categories: String? = nil,
        photo: DocumentPhoto? = nil,
        authenticity: Authenticity
    ) {
        self.provenance = provenance
        self.surname = surname
        self.givenNames = givenNames
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.nationality = nationality
        self.issuingState = issuingState
        self.documentNumber = documentNumber
        self.documentCode = documentCode
        self.dateOfExpiry = dateOfExpiry
        self.placeOfBirth = placeOfBirth
        self.residence = residence
        self.codiceFiscale = codiceFiscale
        self.issuingAuthority = issuingAuthority
        self.dateOfIssue = dateOfIssue
        self.otherNames = otherNames
        self.profession = profession
        self.title = title
        self.personalSummary = personalSummary
        self.telephone = telephone
        self.otherValidDocuments = otherValidDocuments
        self.custodyInformation = custodyInformation
        self.endorsements = endorsements
        self.taxOrExitRequirements = taxOrExitRequirements
        self.categories = categories
        self.photo = photo
        self.authenticity = authenticity
    }

    /// Vollstaendiger Name fuer die Kopfzeile des Ergebnisschirms.
    public var fullName: String {
        [givenNames, surname]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
    }
}
