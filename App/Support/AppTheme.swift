import SwiftUI
import IDReaderCore

/// Die Farben der App, Wert fuer Wert aus der Android-Fassung.
///
/// Warum ein eigenes Farbschema und nicht die Systemfarben: welche Dokumentart
/// gelesen wird, entscheidet darueber, welcher Schluessel verlangt wird und was
/// am Ende im Bericht steht. Wer die Farbe sieht, sieht die Betriebsart, ohne
/// eine Zeile Text zu lesen. Die Identitaetskarte ist blau, der Reisepass braun
/// (die Farben eines Passeinbands), der Fuehrerschein rosé - letzteres keine
/// Wahl, sondern Anhang I der Richtlinie 2006/126/EG, Nummer 3 Buchstabe e: der
/// Untergrund der Karte ist rosa gedruckt.
///
/// Umgeschaltet wird das ganze Schema und nicht einzelne Flaechen. Gaebe es nur
/// einen braunen Kopfbereich, blieben Knoepfe, Textfelder und Blaetter blau, und
/// die App saehe aus, als waere ihr ein Teil misslungen.
struct DocumentPalette: Sendable {

    // Rollen, die aus dem Material-3-Schema der Android-Fassung kommen. Die Namen
    // sind absichtlich dieselben: so lassen sich die beiden Fassungen Wert fuer
    // Wert gegeneinander halten.
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color

    let secondaryContainer: Color
    let onSecondaryContainer: Color

    let tertiaryContainer: Color
    let onTertiaryContainer: Color

    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let onSurfaceVariant: Color

    let surfaceContainerLowest: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color

    let outline: Color
    let outlineVariant: Color

    let error: Color
    let onError: Color
    let errorContainer: Color
    let onErrorContainer: Color

    // Farben, die sich auf keine Systemrolle abbilden lassen: der Vollbild-
    // Lesescreen und die Flaechen der Dokumentgrafik.
    let isDark: Bool
    let tapBackground: Color
    let onTapBackground: Color
    let onTapBackgroundMuted: Color
    let tapAccent: Color

    /// Gruen fuer einen abgeschlossenen Schritt auf dem Lesescreen.
    ///
    /// In beiden Themes derselbe helle Ton: der Lesescreen ist immer dunkel -
    /// dunkelblau im hellen Theme, fast schwarz im dunklen. Ein Gruen, das auf
    /// einem von beiden lesbar ist, ist es auf dem anderen auch.
    let tapDone: Color

    let cardFaceStart: Color
    let cardFaceEnd: Color
    let cardChip: Color

    /// Gruen fuer eine bestaetigte Pruefung auf neutralem Grund.
    let verified: Color
    let onVerified: Color

    /// Gruen fuer das Siegel im getoenten Kopfbereich des Ergebnisschirms.
    ///
    /// Eigene Farbe, weil der Kopfbereich ``primary`` traegt - im hellen Theme
    /// dunkelblau, im dunklen hellblau. Ein Gruenton, der auf dem einen lesbar
    /// ist, verschwindet auf dem anderen.
    let sealVerified: Color
    let sealFailed: Color
}

extension DocumentPalette {

    static func of(_ mode: DocumentMode, dark: Bool) -> DocumentPalette {
        switch (mode, dark) {
        case (.identityCard, false): cardLight
        case (.identityCard, true): cardDark
        case (.passport, false): passportLight
        case (.passport, true): passportDark
        case (.drivingLicence, false): licenceLight
        case (.drivingLicence, true): licenceDark
        }
    }

    /// Flaechen- und Zeichenfarbe einer Dokumentart, fuer Stellen, an denen beide
    /// Arten gleichzeitig vorkommen - im Archiv steht neben einem Pass eine
    /// Identitaetskarte. Dort waeren die Farben des gerade geltenden Schemas
    /// falsch: sie wuerden alle Zeilen gleich einfaerben und damit genau die
    /// Unterscheidung verschlucken, um die es geht.
    static func tint(_ mode: DocumentMode, dark: Bool) -> (container: Color, content: Color) {
        let palette = of(mode, dark: dark)
        return (palette.primaryContainer, palette.primary)
    }

    // -----------------------------------------------------------------------
    // Identitaetskarte - blau
    // -----------------------------------------------------------------------

    static let cardLight = DocumentPalette(
        primary: .hex(0x0B5CB0), onPrimary: .hex(0xFFFFFF),
        primaryContainer: .hex(0xCFE2FF), onPrimaryContainer: .hex(0x052A4A),
        secondaryContainer: .hex(0xD6E4F7), onSecondaryContainer: .hex(0x0F1D2A),
        tertiaryContainer: .hex(0xC3E8FD), onTertiaryContainer: .hex(0x001F2A),
        background: .hex(0xFBFCFF), onBackground: .hex(0x171A1E),
        surface: .hex(0xFBFCFF), onSurface: .hex(0x171A1E),
        onSurfaceVariant: .hex(0x454A52),
        surfaceContainerLowest: .hex(0xFFFFFF),
        surfaceContainer: .hex(0xEDF0F7),
        surfaceContainerHigh: .hex(0xE9ECF3),
        outline: .hex(0x737880), outlineVariant: .hex(0xC4C8D0),
        error: .hex(0xB3261E), onError: .hex(0xFFFFFF),
        errorContainer: .hex(0xF9DEDC), onErrorContainer: .hex(0x410E0B),
        isDark: false,
        tapBackground: .hex(0x0B4F8A), onTapBackground: .hex(0xFFFFFF),
        onTapBackgroundMuted: .hex(0xFFFFFF, opacity: 0.8), tapAccent: .hex(0xFFFFFF),
        tapDone: .hex(0x7FD79F),
        cardFaceStart: .hex(0xF4F8FE), cardFaceEnd: .hex(0xCFE2FF), cardChip: .hex(0xCBB56B),
        verified: .hex(0x1B6B3A), onVerified: .hex(0xFFFFFF),
        // Kopfbereich ist hier dunkelblau, also helle Siegelfarben.
        sealVerified: .hex(0x7FD79F), sealFailed: .hex(0xFFB4AB)
    )

    static let cardDark = DocumentPalette(
        primary: .hex(0xA1C9FF), onPrimary: .hex(0x00325C),
        primaryContainer: .hex(0x00497F), onPrimaryContainer: .hex(0xD3E4FF),
        secondaryContainer: .hex(0x3A4857), onSecondaryContainer: .hex(0xD6E4F7),
        tertiaryContainer: .hex(0x264B5C), onTertiaryContainer: .hex(0xC3E8FD),
        background: .hex(0x0A1420), onBackground: .hex(0xE2E2E6),
        surface: .hex(0x0A1420), onSurface: .hex(0xE2E2E6),
        onSurfaceVariant: .hex(0xC3C7CF),
        surfaceContainerLowest: .hex(0x060D16),
        surfaceContainer: .hex(0x16202C),
        surfaceContainerHigh: .hex(0x202A36),
        outline: .hex(0x8B95A1), outlineVariant: .hex(0x414B57),
        error: .hex(0xF2B8B5), onError: .hex(0x601410),
        errorContainer: .hex(0x8C1D18), onErrorContainer: .hex(0xF9DEDC),
        isDark: true,
        tapBackground: .hex(0x0A1420), onTapBackground: .hex(0xE2E2E6),
        onTapBackgroundMuted: .hex(0x8FA3B8), tapAccent: .hex(0xA1C9FF),
        tapDone: .hex(0x7FD79F),
        cardFaceStart: .hex(0x1E3A56), cardFaceEnd: .hex(0x00497F), cardChip: .hex(0x8A7A45),
        verified: .hex(0x7FD79F), onVerified: .hex(0x00391C),
        // Kopfbereich ist hier hellblau, also dunkle Siegelfarben.
        sealVerified: .hex(0x11562F), sealFailed: .hex(0x8C1D18)
    )

    // -----------------------------------------------------------------------
    // Reisepass - braun mit Gold
    // -----------------------------------------------------------------------

    static let passportLight = DocumentPalette(
        primary: .hex(0x8A5A12), onPrimary: .hex(0xFFFFFF),
        primaryContainer: .hex(0xFBE2BB), onPrimaryContainer: .hex(0x3A2306),
        secondaryContainer: .hex(0xEEE1CD), onSecondaryContainer: .hex(0x251A0B),
        // Oliv als dritte Farbe, nicht noch ein Braunton: der Aufbewahrungshinweis
        // traegt diese Flaeche und soll sich abheben, ohne wie eine Warnung
        // auszusehen.
        tertiaryContainer: .hex(0xDFE6C7), onTertiaryContainer: .hex(0x1D2400),
        background: .hex(0xFFFBF4), onBackground: .hex(0x201B12),
        surface: .hex(0xFFFBF4), onSurface: .hex(0x201B12),
        onSurfaceVariant: .hex(0x524738),
        surfaceContainerLowest: .hex(0xFFFFFF),
        surfaceContainer: .hex(0xF5EDE1),
        surfaceContainerHigh: .hex(0xF0E7DA),
        outline: .hex(0x82766A), outlineVariant: .hex(0xD6C7B2),
        // Rot bleibt Rot: ein Fehler sieht in allen Betriebsarten gleich aus.
        error: .hex(0xB3261E), onError: .hex(0xFFFFFF),
        errorContainer: .hex(0xF9DEDC), onErrorContainer: .hex(0x410E0B),
        isDark: false,
        tapBackground: .hex(0x3A2913), onTapBackground: .hex(0xFFFFFF),
        onTapBackgroundMuted: .hex(0xFFFFFF, opacity: 0.8), tapAccent: .hex(0xF2C879),
        tapDone: .hex(0x7FD79F),
        // Die Datenseite eines Passes: heller Karton, kein Blau.
        cardFaceStart: .hex(0xFDF6EC), cardFaceEnd: .hex(0xF0E4D2), cardChip: .hex(0x8A6430),
        verified: .hex(0x1B6B3A), onVerified: .hex(0xFFFFFF),
        sealVerified: .hex(0x7FD79F), sealFailed: .hex(0xFFB4AB)
    )

    static let passportDark = DocumentPalette(
        primary: .hex(0xF9BB6B), onPrimary: .hex(0x452B00),
        primaryContainer: .hex(0x643F00), onPrimaryContainer: .hex(0xFFDDB6),
        secondaryContainer: .hex(0x52463A), onSecondaryContainer: .hex(0xEEE1CD),
        tertiaryContainer: .hex(0x3E4522), onTertiaryContainer: .hex(0xDFE6C7),
        background: .hex(0x17130D), onBackground: .hex(0xEBE1D4),
        surface: .hex(0x17130D), onSurface: .hex(0xEBE1D4),
        onSurfaceVariant: .hex(0xD3C6B4),
        surfaceContainerLowest: .hex(0x100C07),
        surfaceContainer: .hex(0x221D15),
        surfaceContainerHigh: .hex(0x2D2720),
        outline: .hex(0x988D7E), outlineVariant: .hex(0x4E4639),
        error: .hex(0xF2B8B5), onError: .hex(0x601410),
        errorContainer: .hex(0x8C1D18), onErrorContainer: .hex(0xF9DEDC),
        isDark: true,
        tapBackground: .hex(0x201A12), onTapBackground: .hex(0xEBE1D4),
        onTapBackgroundMuted: .hex(0xB8A991), tapAccent: .hex(0xF2C879),
        tapDone: .hex(0x7FD79F),
        cardFaceStart: .hex(0x3A3126), cardFaceEnd: .hex(0x2A2318), cardChip: .hex(0x8A6430),
        verified: .hex(0x7FD79F), onVerified: .hex(0x00391C),
        sealVerified: .hex(0x11562F), sealFailed: .hex(0x8C1D18)
    )

    // -----------------------------------------------------------------------
    // Fuehrerschein - rosé
    // -----------------------------------------------------------------------

    static let licenceLight = DocumentPalette(
        primary: .hex(0xB01A5B), onPrimary: .hex(0xFFFFFF),
        primaryContainer: .hex(0xFFD6E3), onPrimaryContainer: .hex(0x450019),
        secondaryContainer: .hex(0xFFD9E0), onSecondaryContainer: .hex(0x2B151C),
        // Warmes Braun als dritte Farbe, kein weiterer Rosaton.
        tertiaryContainer: .hex(0xFFDCC2), onTertiaryContainer: .hex(0x2E1500),
        background: .hex(0xFFF8F9), onBackground: .hex(0x201A1C),
        surface: .hex(0xFFF8F9), onSurface: .hex(0x201A1C),
        onSurfaceVariant: .hex(0x534347),
        surfaceContainerLowest: .hex(0xFFFFFF),
        surfaceContainer: .hex(0xFCEAEE),
        surfaceContainerHigh: .hex(0xF7E4E9),
        outline: .hex(0x857477), outlineVariant: .hex(0xD8C2C8),
        error: .hex(0xB3261E), onError: .hex(0xFFFFFF),
        errorContainer: .hex(0xF9DEDC), onErrorContainer: .hex(0x410E0B),
        isDark: false,
        // Kein Auflegebildschirm - die Karte hat keinen Chip. Die Werte sind
        // trotzdem gesetzt, weil das Schema vollstaendig sein muss.
        tapBackground: .hex(0x4A1229), onTapBackground: .hex(0xFFFFFF),
        onTapBackgroundMuted: .hex(0xFFFFFF, opacity: 0.8), tapAccent: .hex(0xFFB0CB),
        tapDone: .hex(0x7FD79F),
        cardFaceStart: .hex(0xFDECF1), cardFaceEnd: .hex(0xF3D3DE), cardChip: .hex(0xB0798D),
        verified: .hex(0x1B6B3A), onVerified: .hex(0xFFFFFF),
        sealVerified: .hex(0x11562F), sealFailed: .hex(0x8C1D18)
    )

    static let licenceDark = DocumentPalette(
        primary: .hex(0xFFB0CB), onPrimary: .hex(0x5E1133),
        primaryContainer: .hex(0x900047), onPrimaryContainer: .hex(0xFFD9E4),
        secondaryContainer: .hex(0x5A3F48), onSecondaryContainer: .hex(0xFFD9E4),
        tertiaryContainer: .hex(0x623F20), onTertiaryContainer: .hex(0xFFDCC2),
        background: .hex(0x191113), onBackground: .hex(0xEFDFE2),
        surface: .hex(0x191113), onSurface: .hex(0xEFDFE2),
        onSurfaceVariant: .hex(0xD5C2C6),
        surfaceContainerLowest: .hex(0x140C0E),
        surfaceContainer: .hex(0x261D1F),
        surfaceContainerHigh: .hex(0x31282A),
        outline: .hex(0x9E8C90), outlineVariant: .hex(0x514347),
        error: .hex(0xF2B8B5), onError: .hex(0x601410),
        errorContainer: .hex(0x8C1D18), onErrorContainer: .hex(0xF9DEDC),
        isDark: true,
        tapBackground: .hex(0x1C1013), onTapBackground: .hex(0xEFDFE2),
        onTapBackgroundMuted: .hex(0xBFA5AC), tapAccent: .hex(0xFFB0CB),
        tapDone: .hex(0x7FD79F),
        cardFaceStart: .hex(0x4B2B36), cardFaceEnd: .hex(0x63384A), cardChip: .hex(0x8A5C6C),
        verified: .hex(0x7FD79F), onVerified: .hex(0x00391C),
        sealVerified: .hex(0x11562F), sealFailed: .hex(0x8C1D18)
    )
}

extension Color {
    /// Ein Wert, wie er in der Android-Fassung steht: 0xRRGGBB.
    static func hex(_ value: UInt32, opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// ---------------------------------------------------------------------------

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = DocumentPalette.cardLight
}

extension EnvironmentValues {
    var palette: DocumentPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Schriftstile, die ueber das Systemraster hinausgehen.
///
/// Der Entwurf benutzt 11, 13, 15, 17 und 20 Punkt. Alle Stile sind relativ zu
/// einem Textstil angelegt (`relativeTo:`), damit sie mit der Systemschrift
/// mitwachsen - das war unter Compose durch `sp` selbstverstaendlich und ist es
/// hier nicht.
enum AppType {
    /// Beschriftung der grossen Knoepfe und der Titelzeile.
    static let actionLarge = Font.system(size: 17, weight: .medium)
    /// Beschriftung der kleinen Knoepfe: „Ändern", „Eingabe".
    static let actionSmall = Font.system(size: 13, weight: .medium)
    /// Die zweite Zeile im geteilten Leseknopf, und der Vorbehalt „ungeprüft".
    ///
    /// Der Entwurf hatte hier zuerst 9 Punkt und ist auf 11 gegangen. Kleiner
    /// darf es nicht werden: bei 200 Prozent Systemschrift steht dieser Text
    /// neben einem 17-Punkt-Geschwister in derselben Knopfhoehe.
    static let microLabel = Font.system(size: 11, weight: .medium)
    /// Der Titel eines eigenen Bildschirms - im Archiv „5 Scans".
    static let screenTitle = Font.system(size: 20, weight: .medium)
    /// Die Versalzeile ueber einer Tagesgruppe im Archiv.
    static let groupLabel = Font.system(size: 11, weight: .medium)
    /// Ueberschrift einer Schrittkarte.
    static let cardHeading = Font.system(size: 15, weight: .medium)
    /// Die Ziffer in der nummerierten Marke.
    static let stepBadge = Font.system(size: 13, weight: .bold)

    /// Die Schrift der abgelesenen Werte.
    ///
    /// Nichtproportional, weil der Wert abgeschrieben ist und nicht formuliert -
    /// und weil sich Ziffern dann untereinander ausrichten. Anders als unter
    /// Android braucht es dafuer keinen Notbehelf: `SF Mono` liegt auf dem
    /// System, und `.monospaced` erreicht sie.
    static func mono(_ size: CGFloat, tracking: CGFloat = 0) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    /// Die CAN in der Schluesselzeile: weit gesperrt, damit sich sechs Ziffern
    /// zaehlen lassen.
    static let monoCan = mono(18)
    static let monoRowValue = mono(14)
    static let monoField = mono(16)
    static let monoDigitBox = mono(24)
}
