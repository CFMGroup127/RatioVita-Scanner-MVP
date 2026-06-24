import CryptoKit
import Foundation
import Security

/// iCloud Keychain–synced signing key — same SPID on Mac, iPad, and iPhone when Keychain sync is enabled.
enum SovereignProfileSeedStore {
    private static let service = "com.ratiovita.sovereign.signing"
    private static let account = "sovereign-profile-ed25519-v1"

    static func loadOrCreateSigningKey() throws -> Curve25519.Signing.PrivateKey {
        if let existing = try readPrivateKey() {
            return existing
        }
        let fresh = Curve25519.Signing.PrivateKey()
        try savePrivateKey(fresh)
        return fresh
    }

    static func readPrivateKey() throws -> Curve25519.Signing.PrivateKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status: status)
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    private static func savePrivateKey(_ key: Curve25519.Signing.PrivateKey) throws {
        let data = key.rawRepresentation
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try deletePrivateKey()
            let retry = SecItemAdd(add as CFDictionary, nil)
            guard retry == errSecSuccess else { throw KeychainError.unhandled(status: retry) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    private static func deletePrivateKey() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    enum KeychainError: LocalizedError {
        case unhandled(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                return "Sovereign Keychain error (status \(status))."
            }
        }
    }
}
