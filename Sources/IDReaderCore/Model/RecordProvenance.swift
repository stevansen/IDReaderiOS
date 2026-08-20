import Foundation

/// Woher die Angaben eines Datensatzes stammen.
///
/// Die wichtigste Unterscheidung, die diese App trifft. Bis zur dritten
/// Dokumentart gab es nur eine Frage - "ist die Pruefung aufgegangen?" - und
/// eine Antwort darauf, ``Authenticity``. Der Fuehrerschein stellt die Frage
/// davor: **ist hier ueberhaupt etwas, das sich pruefen liesse?**
///
/// Diese Frage mit einem Wert der ersten Achse zu beantworten waere der Fehler.
/// "Nicht geprueft" heisst, es haette geprueft werden koennen und wurde nicht.
/// Beim Fuehrerschein gibt es nichts zu pruefen: kein Chip, keine Signatur,
/// keine Pruefziffer.
public enum RecordProvenance: String, Sendable, Codable, CaseIterable {
    /// Vom Chip gelesen und kryptografisch geprueft - CIE und Reisepass.
    case chip = "CHIP"

    /// Aus einem Foto erkannt. Nichts daran ist bestaetigt: weder die Angaben
    /// noch das Dokument, noch dass ueberhaupt ein solches fotografiert wurde.
    case photo = "PHOTO"
}

/// Woher der eingegebene Zugangsschluessel stammt. Rein fuer die Anzeige.
///
/// Was ``scanned`` wert ist, unterscheidet sich zwischen den Dokumentarten:
/// beim Pass gehen die drei Pruefziffern der MRZ auf, die Erkennung ist also
/// nachweislich richtig abgelesen. Bei der CIE ist die CAN eine nackte
/// sechsstellige Zahl ohne Pruefziffer - offline laesst sich nichts
/// bestaetigen. Deshalb steht hier nur die Herkunft; welche Aussage daraus
/// folgt, entscheidet die jeweilige Maske.
public enum InputSource: Sendable {
    case typed
    case scanned
}

/// Grobe Phase des Lesevorgangs.
public enum ReadPhase: Sendable, CaseIterable {
    case connect
    case secure
    case data
    case verify
}

/// Schritte des Lesevorgangs - dient der Fortschrittsanzeige.
public enum ReadStep: Sendable, CaseIterable {
    case waitingForCard
    case connecting
    case authenticating
    case readingDG1
    case readingDG11
    case readingDG2
    case readingSOD
    case verifying
    case done

    public var progress: Double {
        switch self {
        case .waitingForCard: 0
        case .connecting: 0.08
        case .authenticating: 0.20
        case .readingDG1: 0.38
        case .readingDG11: 0.50
        case .readingDG2: 0.72
        case .readingSOD: 0.86
        case .verifying: 0.94
        case .done: 1
        }
    }

    public var phase: ReadPhase {
        switch self {
        case .waitingForCard, .connecting: .connect
        case .authenticating: .secure
        case .readingDG1, .readingDG11, .readingDG2, .readingSOD: .data
        case .verifying, .done: .verify
        }
    }
}

/// Geschlecht laut MRZ.
public enum Gender: String, Sendable, Codable {
    case male = "MALE"
    case female = "FEMALE"
    case unknown = "UNKNOWN"
}
