import CryptoKit
import Foundation
import Security

/// Der Archivschluessel im Schluesselbund des Geraets.
///
/// ## Warum nicht die Secure Enclave
///
/// Das Android-Original legt den Schluessel im Android-Keystore ab, wo er die
/// Hardware nicht verlaesst. Das naechstliegende Gegenstueck waere die Secure
/// Enclave - die fuehrt aber nur EC-Schluessel (P-256), also muesste der
/// eigentliche Datenschluessel damit erst umhuellt und die Huelle daneben gelegt
/// werden. Zwei Schluessel, zwei Fehlerfaelle, ein Verfahren mehr zu pruefen.
///
/// Der Schluesselbund mit ``kSecAttrAccessibleWhenUnlockedThisDeviceOnly`` gibt,
/// worauf es hier ankommt: der Schluessel wird nie gesichert, nie auf ein anderes
/// Geraet uebertragen, und er ist nur bei entsperrtem Geraet zu haben - dieselbe
/// Zusage wie `setUnlockedDeviceRequired(true)` auf der Android-Seite. Wer die
/// Archivdatei kopiert, hat verschluesselten Datenmuell.
///
/// Die Umhuellung durch die Secure Enclave bleibt der naechste Schritt, wenn
/// jemand ein Angriffsmodell nennt, in dem sie etwas hinzufuegt: siehe
/// docs/ANDROID-TO-IOS.md.
public struct KeychainArchiveKeyStore: ArchiveKeyStore {

    private let account: String
    private let service: String

    public init(service: String = "IDReader.archive", account: String = "document-store") {
        self.service = service
        self.account = account
    }

    public func key() throws -> SymmetricKey {
        if let existing = try read() { return existing }

        let fresh = SymmetricKey(size: .bits256)
        try write(fresh)
        return fresh
    }

    public func discardKey() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // -----------------------------------------------------------------------

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func read() throws -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, data.count == 32 else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            // Ein Fehler beim *Lesen* ist etwas anderes als ein fehlender
            // Schluessel: die Datei koennte noch zu retten sein. Also melden statt
            // stillschweigend einen neuen Schluessel erzeugen - das haette das
            // Archiv unlesbar gemacht und wie Datenverlust ausgesehen.
            throw ArchiveError.keychain(status)
        }
    }

    private func write(_ key: SymmetricKey) throws {
        var attributes = baseQuery()
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw ArchiveError.keychain(status)
        }
    }
}
