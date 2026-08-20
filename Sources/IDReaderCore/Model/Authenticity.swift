import Foundation

/// Gesamturteil der Echtheitspruefung.
public enum AuthenticityStatus: String, Sendable, Codable {
    /// Es gibt nichts zu pruefen.
    ///
    /// Nicht dasselbe wie ``notChecked``: dort waere eine Pruefung moeglich
    /// gewesen und ist unterblieben. Hier fehlt die Grundlage - kein Chip,
    /// keine Signatur, keine Pruefziffer. Ein eigener Wert und kein Sonderfall
    /// von "nicht geprueft", damit der Compiler jede Stelle anzeigt, die ein
    /// Urteil darstellt, und niemand dort versehentlich ein Siegel malt.
    case unverifiable = "UNVERIFIABLE"

    /// Alle Teilpruefungen bestanden - die Karte ist echt und unveraendert.
    case verified = "VERIFIED"

    /// Mindestens eine Teilpruefung ist fehlgeschlagen.
    case failed = "FAILED"

    /// Pruefung konnte nicht durchgefuehrt werden (z. B. EF.SOD nicht lesbar).
    case notChecked = "NOT_CHECKED"
}

/// Grund, warum die Pruefung kein positives Ergebnis hatte.
///
/// Bewusst ohne Text: die Meldungen liegen im Lokalisierungskatalog.
public enum AuthenticityFailure: String, Sendable, Codable {
    case sodUnavailable = "SOD_UNAVAILABLE"
    case dataGroupMismatch = "DATA_GROUP_MISMATCH"
    case signatureInvalid = "SIGNATURE_INVALID"
    case noTrustAnchor = "NO_TRUST_ANCHOR"
    case chainInvalid = "CHAIN_INVALID"
    case error = "ERROR"

    /// Die Karte kuendigt im Security Object eine Chip-Authentisierung an, sie
    /// ist aber nicht gelungen. Genau so verhaelt sich eine Kopie, auf die die
    /// Datengruppen eines echten Ausweises geschrieben wurden.
    case chipNotAuthentic = "CHIP_NOT_AUTHENTIC"
}

/// Ergebnis der Passive Authentication nach ICAO 9303 Teil 11.
///
/// Die Pruefung besteht aus drei voneinander unabhaengigen Schritten. Nur wenn
/// alle drei zutreffen, sind die *Daten* echt UND unveraendert:
///
/// 1. ``dataGroupsIntact`` - die Hashes der gelesenen Datengruppen stehen so im
///    Security Object.
/// 2. ``signatureValid`` - die Signatur des Security Objects passt zum
///    Dokumentensignierer-Zertifikat (DSC) aus dem SOD selbst.
/// 3. ``chainTrusted`` - das DSC wurde von einer hinterlegten italienischen
///    CSCA ausgestellt. Erst das macht aus "irgendwer hat signiert" ein "der
///    Staat Italien hat signiert".
///
/// Ohne Schritt 3 koennte jemand eine Karte mit selbst erzeugtem Schluesselpaar
/// bespielen, und die Schritte 1 und 2 waeren trotzdem gruen.
///
/// Diese drei Schritte beweisen nicht, dass der *Chip* das Original ist. Wer
/// alle Datengruppen samt Security Object auf einen leeren Chip kopiert, kommt
/// hier durch. Diese Luecke schliesst ``chipAuthenticated``: der Chip weist
/// nach, dass er den privaten Schluessel zum oeffentlichen Schluessel aus DG14
/// besitzt. Das zaehlt nur, weil Schritt 1 auch den Hash von DG14 gegen das
/// signierte Security Object prueft.
public struct Authenticity: Sendable, Codable, Equatable {
    public var status: AuthenticityStatus
    public var dataGroupsIntact: Bool
    public var signatureValid: Bool
    public var chainTrusted: Bool

    /// Ob die Karte laut Security Object ueberhaupt eine Chip-Authentisierung
    /// anbietet, also DG14 auffuehrt.
    ///
    /// Bewusst aus dem signierten Security Object abgeleitet und nicht daraus,
    /// ob DG14 lesbar war: sonst kaeme eine Kopie damit durch, DG14 einfach
    /// weglassen.
    public var chipAuthenticationExpected: Bool
    public var chipAuthenticated: Bool

    /// Gepruefte Datengruppen-Nummern, z. B. [1, 2, 11].
    public var checkedDataGroups: [Int]
    /// Datengruppen, deren Hash nicht passte.
    public var mismatchedDataGroups: [Int]

    public var signerName: String?
    public var trustAnchorName: String?
    public var digestAlgorithm: String?
    public var failure: AuthenticityFailure?

    public init(
        status: AuthenticityStatus,
        dataGroupsIntact: Bool = false,
        signatureValid: Bool = false,
        chainTrusted: Bool = false,
        chipAuthenticationExpected: Bool = false,
        chipAuthenticated: Bool = false,
        checkedDataGroups: [Int] = [],
        mismatchedDataGroups: [Int] = [],
        signerName: String? = nil,
        trustAnchorName: String? = nil,
        digestAlgorithm: String? = nil,
        failure: AuthenticityFailure? = nil
    ) {
        self.status = status
        self.dataGroupsIntact = dataGroupsIntact
        self.signatureValid = signatureValid
        self.chainTrusted = chainTrusted
        self.chipAuthenticationExpected = chipAuthenticationExpected
        self.chipAuthenticated = chipAuthenticated
        self.checkedDataGroups = checkedDataGroups
        self.mismatchedDataGroups = mismatchedDataGroups
        self.signerName = signerName
        self.trustAnchorName = trustAnchorName
        self.digestAlgorithm = digestAlgorithm
        self.failure = failure
    }

    /// Fuer ein Dokument, an dem es nichts zu pruefen gibt.
    ///
    /// Ohne Grund, denn es ist keiner: eine Fahrerlaubnis hat keinen Chip, und
    /// das ist kein Fehlschlag, sondern die Bauart des Dokuments. Jeder der
    /// vorhandenen Gruende wuerde behaupten, eine Pruefung sei versucht worden.
    public static let unverifiable = Authenticity(status: .unverifiable)

    /// Ergebnis, wenn gar nicht geprueft werden konnte.
    public static func notChecked(_ failure: AuthenticityFailure) -> Authenticity {
        Authenticity(status: .notChecked, failure: failure)
    }
}
