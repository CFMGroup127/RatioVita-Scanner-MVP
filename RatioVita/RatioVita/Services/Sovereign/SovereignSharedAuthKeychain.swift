import Foundation
import Security

/// iCloud Keychain–synced Firebase identity anchor for AirPods-like multi-device linking.
enum SovereignSharedAuthKeychain {
    static let service = "com.cfmgroup.sovereign.shared-auth"
    static let account = "firebase-linked-uid-v1"

    struct LinkedCredential: Codable, Sendable {
        var uid: String
        var savedAt: Date
    }

    private static let sharedAccessGroupSuffix = "com.cfmgroup.sovereign"

    private static var sharedAccessGroup: String? {
        guard let groups = Bundle.main.object(forInfoDictionaryKey: "keychain-access-groups") as? [String] else {
            return nil
        }
        return groups.first { $0.hasSuffix(sharedAccessGroupSuffix) }
    }

    static func readLinkedUID() -> String? {
        (try? readCredential())?.uid
    }

    static func readCredential() throws -> LinkedCredential? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        if let group = sharedAccessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status: status)
        }
        return try JSONDecoder().decode(LinkedCredential.self, from: data)
    }

    static func saveLinkedUID(_ uid: String) throws {
        let payload = LinkedCredential(uid: uid, savedAt: .now)
        let data = try JSONEncoder().encode(payload)
        let add: [String: Any] = {
            var payload: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecAttrSynchronizable as String: true,
            ]
            if let group = sharedAccessGroup {
                payload[kSecAttrAccessGroup as String] = group
            }
            return payload
        }()
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try deleteCredential()
            let retry = SecItemAdd(add as CFDictionary, nil)
            guard retry == errSecSuccess else { throw KeychainError.unhandled(status: retry) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    static func deleteCredential() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        if let group = sharedAccessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
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
                return "Sovereign shared auth Keychain error (status \(status))."
            }
        }
    }
}
