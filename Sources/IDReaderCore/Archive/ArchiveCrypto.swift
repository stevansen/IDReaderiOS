import CryptoKit
import Foundation

/// Woher der Schluessel des Archivs kommt.
///
/// Ein Protokoll und keine feste Anbindung, weil die beiden Seiten
/// unterschiedliche Antworten brauchen: auf dem Geraet ist es der Schluesselbund,
/// im Test ein Schluessel im Arbeitsspeicher. Ohne diese Trennung braeuchten die
/// Archivtests einen signierten Prozess mit Keychain-Berechtigung, und damit
/// waeren sie nicht mehr unter `swift test` zu haben.
public protocol ArchiveKeyStore: Sendable {
    /// Der Schluessel des Archivs; wird beim ersten Aufruf erzeugt.
    func key() throws -> SymmetricKey
    /// Verwirft den Schluessel. Nur fuer den Fall, dass das Archiv selbst
    /// verworfen wird.
    func discardKey()
}

/// Verschluesselung des Archivs: AES-256-GCM.
///
/// Der Aufbau der Datei ist derselbe wie im Android-Original - ein Byte
/// IV-Laenge, IV, Chiffrat -, damit ein Archiv von dort mit demselben Schluessel
/// hier lesbar waere. Praktisch kommt das nicht vor (die Schluessel verlassen ihr
/// Geraet nicht), aber ein Format ohne Grund zu aendern kostet nur die
/// Vergleichbarkeit.
public struct ArchiveCrypto: Sendable {

    private let keys: ArchiveKeyStore

    public init(keys: ArchiveKeyStore) {
        self.keys = keys
    }

    public func encrypt(_ plain: Data) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plain, using: try keys.key(), nonce: nonce)
        let iv = Data(nonce)

        var out = Data()
        out.append(UInt8(iv.count))
        out.append(iv)
        // GCM-Marke hinten anhaengen, wie es die Java-Cipher-Schnittstelle tut.
        // CryptoKit haelt Chiffrat und Marke getrennt; Java liefert sie in einem
        // Stueck. Das Format soll dem Original folgen, nicht der Bibliothek.
        out.append(sealed.ciphertext)
        out.append(sealed.tag)
        return out
    }

    public func decrypt(_ payload: Data) throws -> Data {
        guard !payload.isEmpty else { throw ArchiveError.emptyFile }
        let ivLength = Int(payload[payload.startIndex])
        guard ivLength >= 1, ivLength <= maxIvLength, payload.count > 1 + ivLength + tagLength else {
            throw ArchiveError.implausibleHeader
        }

        let ivStart = payload.index(payload.startIndex, offsetBy: 1)
        let bodyStart = payload.index(ivStart, offsetBy: ivLength)
        let tagStart = payload.index(payload.endIndex, offsetBy: -tagLength)

        let sealed = try AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: payload[ivStart..<bodyStart]),
            ciphertext: payload[bodyStart..<tagStart],
            tag: payload[tagStart...]
        )
        return try AES.GCM.open(sealed, using: try keys.key())
    }

    public func discardKey() { keys.discardKey() }

    private let maxIvLength = 16
    private let tagLength = 16
}

public enum ArchiveError: Error, Sendable {
    case emptyFile
    case implausibleHeader
    case keychain(OSStatus)
    case renameFailed
}

/// Ein Schluessel im Arbeitsspeicher, fuer Tests und Vorschauen.
public final class InMemoryArchiveKeyStore: ArchiveKeyStore, @unchecked Sendable {
    private var stored: SymmetricKey?
    private let lock = NSLock()

    public init(key: SymmetricKey? = nil) {
        stored = key
    }

    public func key() throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if let stored { return stored }
        let fresh = SymmetricKey(size: .bits256)
        stored = fresh
        return fresh
    }

    public func discardKey() {
        lock.lock()
        stored = nil
        lock.unlock()
    }
}
