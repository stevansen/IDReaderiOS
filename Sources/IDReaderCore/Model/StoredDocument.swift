import Foundation

/// Ein aufbewahrter Lesevorgang.
public struct StoredDocument: Sendable, Equatable, Identifiable {
    public var data: DocumentData
    /// Zeitpunkt des Lesevorgangs, in Millisekunden seit 1970.
    ///
    /// Millisekunden und kein `Date`: das Archivformat ist dasselbe wie unter
    /// Android, und ein Datensatz, der dort geschrieben wurde, soll sich hier
    /// lesen lassen. Ein `TimeInterval` waere die naheliegende Wahl gewesen und
    /// haette das Format still um Bruchteile verschoben.
    public var storedAt: Int64
    /// Kennung, die der Chip beim Anlegen ohne Authentisierung gemeldet hat, als
    /// Hex.
    ///
    /// Auf iOS praktisch immer nil: `NFCTagReaderSession` liefert bei
    /// ISO7816-Tags keine stabile Kennung, und Ausweisdokumente ziehen sie nach
    /// ICAO 9303 bei jedem Auflegen ohnehin neu. Das Feld bleibt, damit ein unter
    /// Android geschriebenes Archiv lesbar ist.
    public var cardId: String?

    /// Die CAN, mit der gelesen wurde.
    ///
    /// Liegt mit im verschluesselten Archiv, damit ein erneutes Eintippen
    /// derselben CAN den vorhandenen Eintrag findet, ohne die Karte auflegen zu
    /// muessen.
    ///
    /// Sicherheitlich vertretbar: im selben Archiv stehen ohnehin die
    /// vollstaendigen Personendaten, die deutlich schutzwuerdiger sind als die
    /// CAN - und die CAN steht auf der Karte aufgedruckt und ist ohne die Karte in
    /// der Hand wertlos.
    public var can: String

    public init(data: DocumentData, storedAt: Int64, cardId: String?, can: String) {
        self.data = data
        self.storedAt = storedAt
        self.cardId = cardId
        self.can = can
    }

    /// Kennung des Datensatzes.
    ///
    /// Zeitpunkt plus Dokumentennummer: zwei Lesevorgaenge in derselben
    /// Millisekunde gibt es nicht, damit ist das eindeutig und bleibt ueber
    /// Speichern und Laden hinweg gleich - ohne eine zusaetzlich zu verwaltende
    /// Nummer.
    public var id: String { "\(storedAt)-\(data.documentNumber)" }

    /// Schluessel, der die Person bezeichnet - nicht die Karte.
    ///
    /// Der Codice Fiscale bleibt ueber einen Kartenwechsel hinweg gleich und ist
    /// deshalb der bessere Schluessel. Fehlt er auf der Karte, muss die
    /// Dokumentennummer einstehen.
    public var identityKey: String {
        if let cf = data.codiceFiscale?.uppercased(),
           !cf.trimmingCharacters(in: .whitespaces).isEmpty {
            return cf
        }
        return data.documentNumber.uppercased()
    }

    /// Ablaufdatum als vergleichbare Zahl (JJJJMMTT), 0 wenn unlesbar.
    ///
    /// Damit laesst sich entscheiden, welches von zwei Dokumenten derselben
    /// Person das neuere ist.
    public var expiryKey: Int {
        let parts = data.dateOfExpiry.split(separator: ".")
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2])
        else { return 0 }
        return year * 10_000 + month * 100 + day
    }

    /// Zeitpunkt als `Date`, fuer die Anzeige.
    public var storedDate: Date {
        Date(timeIntervalSince1970: Double(storedAt) / 1000)
    }
}

/// Jetzt, in Millisekunden seit 1970 - dieselbe Einheit wie im Archivformat.
public func currentTimeMillis() -> Int64 {
    Int64((Date().timeIntervalSince1970 * 1000).rounded())
}
