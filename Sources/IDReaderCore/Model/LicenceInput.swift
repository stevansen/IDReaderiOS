import Foundation

/// Die Felder einer Fahrerlaubnis, so wie sie in der Maske stehen.
///
/// Anders als bei Karte und Pass ist das hier **kein Schluessel**, sondern schon
/// der Datensatz. Es gibt nichts aufzuschliessen: was in diesen Feldern steht,
/// wird gespeichert, exportiert und landet im Bericht.
///
/// Deshalb sind alle Felder frei bearbeitbar. Die Texterkennung fuellt sie vor,
/// aber sie kann sich verlesen, und niemand kann ihr widersprechen - es gibt
/// keine Pruefziffer und keinen Chip, der sich verweigert. Die einzige Instanz,
/// die einen Lesefehler bemerkt, ist der Mensch mit dem Dokument in der Hand.
/// Also gehoert ihm das letzte Wort, und die Maske ist eine Vorlage zum
/// Gegenlesen, kein Ergebnis.
public struct LicenceInput: Sendable, Equatable {
    public var surname: String = ""
    public var givenNames: String = ""
    public var dateOfBirth: String = ""
    public var placeOfBirth: String = ""
    public var dateOfIssue: String = ""
    public var dateOfExpiry: String = ""

    /// Die ausstellende Stelle. Steht in der Maske nicht.
    ///
    /// Auf jeder neu ausgegebenen italienischen Fahrerlaubnis steht hier
    /// dasselbe - das Ministerium ueber sein zentrales Amt. Ein Feld, das immer
    /// gleich ausgefuellt ist, kostet den Benutzer eine Zeile Aufmerksamkeit und
    /// bringt ihm nichts; im Datensatz gefuehrt wird es trotzdem, weil der
    /// Bericht danach fragt.
    ///
    /// Gelesen wird es weiter aus dem Foto, und was dort steht, hat Vorrang: die
    /// aelteren, von einer Provinz ausgegebenen Karten tragen `MC-<Provinz>`.
    public var issuingAuthority: String = ""
    public var number: String = ""
    public var categories: String = ""

    public init() {}

    /// Ob sich das Speichern lohnt.
    ///
    /// Bewusst niedrig angesetzt: Nachname und Nummer. Mehr zu verlangen hiesse,
    /// einen unvollstaendig lesbaren Fuehrerschein gar nicht erfassen zu koennen,
    /// und ein Teildatensatz mit dem Hinweis, woher er stammt, ist mehr wert als
    /// keiner.
    public var isComplete: Bool {
        !surname.trimmingCharacters(in: .whitespaces).isEmpty
            && !number.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Ob die Nummer der bekannten Bauform entspricht.
    ///
    /// Zehn Zeichen, entweder zwei Buchstaben mit sieben Ziffern und einem
    /// Buchstaben, oder eine Zweitschrift mit dem Vorsatz U1. Das ist **keine**
    /// Pruefung: der abschliessende Buchstabe ist zwar amtlich ein Pruefzeichen
    /// (Rundschreiben des MIT vom 18.10.2011), sein Verfahren ist aber nie
    /// veroeffentlicht worden. Es bleibt bei der Form, und die verraet nur grobe
    /// Verlesungen.
    public var numberLooksOdd: Bool {
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !LicenceInput.territorial.matches(trimmed)
            && !LicenceInput.duplicate.matches(trimmed)
    }

    /// Baut den Datensatz, der gespeichert wird.
    public func toDocumentData() -> DocumentData {
        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespaces)
        }
        func nilIfBlank(_ value: String) -> String? {
            let t = trimmed(value)
            return t.isEmpty ? nil : t
        }

        return DocumentData(
            provenance: .photo,
            surname: trimmed(surname),
            givenNames: trimmed(givenNames),
            dateOfBirth: trimmed(dateOfBirth),
            gender: .unknown,
            // Steht nicht auf der Karte. Leer statt "ITA" geraten: eine
            // Fahrerlaubnis sagt nichts ueber die Staatsangehoerigkeit.
            nationality: "",
            issuingState: nil,
            documentNumber: trimmed(number),
            documentCode: nil,
            dateOfExpiry: trimmed(dateOfExpiry),
            placeOfBirth: nilIfBlank(placeOfBirth),
            // Feld 8, der Wohnsitz, wird auf italienischen Karten seit 2013 nicht
            // mehr gedruckt.
            residence: nil,
            codiceFiscale: nil,
            issuingAuthority: nilIfBlank(issuingAuthority) ?? LicenceInput.defaultAuthority,
            dateOfIssue: nilIfBlank(dateOfIssue),
            categories: nilIfBlank(categories),
            photo: nil,
            authenticity: .unverifiable
        )
    }

    /// Uebernimmt, was die Erkennung gefunden hat.
    public static func from(_ fields: LicenceScan.Fields) -> LicenceInput {
        var input = LicenceInput()
        input.surname = fields.surname ?? ""
        input.givenNames = fields.givenNames ?? ""
        input.dateOfBirth = fields.dateOfBirth ?? ""
        input.placeOfBirth = fields.placeOfBirth ?? ""
        input.dateOfIssue = fields.dateOfIssue ?? ""
        input.dateOfExpiry = fields.dateOfExpiry ?? ""
        input.issuingAuthority = fields.issuingAuthority ?? ""
        input.number = fields.number ?? ""
        input.categories = fields.categories ?? ""
        return input
    }

    /// Die ausstellende Stelle neuer italienischer Fahrerlaubnisse.
    ///
    /// Ministero delle Infrastrutture e dei Trasporti, Ufficio Centrale
    /// Operativo. Steht seit der Zentralisierung auf jeder neu ausgegebenen Karte
    /// und auf allen acht vermessenen Aufnahmen.
    public static let defaultAuthority = "MIT-UCO"

    /// Zwei Buchstaben, sieben Ziffern, ein Buchstabe.
    private static let territorial = Pattern("[A-Z]{2}\\d{7}[A-Z]")
    /// Zweitschrift: Vorsatz U1, sieben Zeichen, ein Buchstabe.
    private static let duplicate = Pattern("U1[A-Z0-9]{7}[A-Z]")
}
