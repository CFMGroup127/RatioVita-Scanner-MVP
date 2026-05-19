import Foundation
import Security

/// Secure, **iCloud Keychain–synced** storage for the Gemini API key (complements `UserDefaults` / `@AppStorage`).
enum GeminiAPIKeyKeychain {
    private static let service = "com.ratiovita.gemini"
    private static let account = "apiKey"

    static func readTrimmed() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        let s = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    static func saveTrimmed(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try delete()
        guard !trimmed.isEmpty else { return }
        let data = Data(trimmed.utf8)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Keychain save failed (status \(status)).",
            ])
        }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Keychain delete failed (status \(status)).",
            ])
        }
    }

    /// One-time: copy `UserDefaults` key into Keychain so iPad/iPhone share it via iCloud Keychain when enabled.
    static func migrateFromUserDefaultsIfNeeded() {
        let udKey = "geminiAPIKey"
        let trimmed = UserDefaults.standard.string(forKey: udKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        if let existing = readTrimmed(), !existing.isEmpty { return }
        try? saveTrimmed(trimmed)
    }
}
