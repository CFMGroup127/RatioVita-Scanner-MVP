import Foundation
import Security

/// Keychain-backed credentials for supplier email ingestion (OAuth tokens, IMAP app passwords).
enum SecureIngestionVaultStore {
    enum Provider: String, CaseIterable, Identifiable, Codable {
        case gmailOAuth
        case outlookOAuth
        case customIMAP

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gmailOAuth: "Gmail"
            case .outlookOAuth: "Outlook / Microsoft 365"
            case .customIMAP: "Custom IMAP"
            }
        }

        var systemImage: String {
            switch self {
            case .gmailOAuth: "envelope.fill"
            case .outlookOAuth: "envelope.badge.fill"
            case .customIMAP: "server.rack"
            }
        }

        var usesOAuth: Bool {
            switch self {
            case .gmailOAuth, .outlookOAuth: true
            case .customIMAP: false
            }
        }
    }

    private static let service = "com.ratiovita.secure-ingestion-vault"
    private static let connectedKey = "com.ratiovita.ingestion.connectedProviders"
    private static let imapHostKey = "com.ratiovita.ingestion.imapHost"
    private static let imapUserKey = "com.ratiovita.ingestion.imapUser"

    static func isConnected(_ provider: Provider) -> Bool {
        connectedProviderIDs().contains(provider.rawValue)
    }

    static func markConnected(_ provider: Provider) {
        var ids = connectedProviderIDs()
        ids.insert(provider.rawValue)
        UserDefaults.standard.set(Array(ids), forKey: connectedKey)
    }

    static func disconnect(_ provider: Provider) throws {
        var ids = connectedProviderIDs()
        ids.remove(provider.rawValue)
        UserDefaults.standard.set(Array(ids), forKey: connectedKey)
        try deleteSecret(account: provider.rawValue)
        if provider == .customIMAP {
            UserDefaults.standard.removeObject(forKey: imapHostKey)
            UserDefaults.standard.removeObject(forKey: imapUserKey)
        }
    }

    static func saveOAuthPlaceholderToken(for provider: Provider, token: String) throws {
        guard provider.usesOAuth else { return }
        try saveSecret(token, account: provider.rawValue)
        markConnected(provider)
    }

    static func saveIMAPCredentials(host: String, username: String, appPassword: String) throws {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty, !trimmedPassword.isEmpty else { return }

        UserDefaults.standard.set(trimmedHost, forKey: imapHostKey)
        UserDefaults.standard.set(trimmedUser, forKey: imapUserKey)
        try saveSecret(trimmedPassword, account: Provider.customIMAP.rawValue)
        markConnected(.customIMAP)
    }

    static var imapHost: String {
        UserDefaults.standard.string(forKey: imapHostKey) ?? ""
    }

    static var imapUsername: String {
        UserDefaults.standard.string(forKey: imapUserKey) ?? ""
    }

    private static func connectedProviderIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: connectedKey) ?? [])
    }

    private static func saveSecret(_ value: String, account: String) throws {
        try deleteSecret(account: account)
        let data = Data(value.utf8)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Secure vault save failed (status \(status)).",
            ])
        }
    }

    private static func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Secure vault delete failed (status \(status)).",
            ])
        }
    }
}
