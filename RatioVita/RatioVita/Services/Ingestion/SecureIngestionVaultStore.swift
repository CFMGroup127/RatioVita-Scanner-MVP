import Foundation
import Security

/// Keychain-backed credentials for supplier email ingestion (OAuth tokens, multi-inbox IMAP).
enum SecureIngestionVaultStore {

    // MARK: - Provider kinds

    enum Provider: String, CaseIterable, Identifiable, Codable {
        case gmailOAuth
        case outlookOAuth

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gmailOAuth: "Gmail"
            case .outlookOAuth: "Outlook / Microsoft 365"
            }
        }

        var systemImage: String {
            switch self {
            case .gmailOAuth: "envelope.fill"
            case .outlookOAuth: "envelope.badge.fill"
            }
        }

        var usesOAuth: Bool { true }
    }

    enum SecureInboxKind: String, CaseIterable, Identifiable, Codable {
        case yahoo
        case iCloud
        case outlookHotmail
        case customIMAP

        var id: String { rawValue }

        var title: String {
            switch self {
            case .yahoo: "Yahoo Mail"
            case .iCloud: "iCloud / Apple Mail"
            case .outlookHotmail: "Outlook / Hotmail"
            case .customIMAP: "Custom IMAP"
            }
        }

        var systemImage: String {
            switch self {
            case .yahoo: "y.circle.fill"
            case .iCloud: "icloud.fill"
            case .outlookHotmail: "envelope.badge.fill"
            case .customIMAP: "server.rack"
            }
        }

        var defaultIMAPHost: String {
            switch self {
            case .yahoo: "imap.mail.yahoo.com"
            case .iCloud: "imap.mail.me.com"
            case .outlookHotmail: "outlook.office365.com"
            case .customIMAP: ""
            }
        }
    }

    struct SecureInboxAccount: Identifiable, Codable, Equatable {
        let id: UUID
        var kind: SecureInboxKind
        var emailAddress: String
        var imapHost: String
        var isIngestionEnabled: Bool
        var linkedAt: Date

        init(
            id: UUID = UUID(),
            kind: SecureInboxKind,
            emailAddress: String,
            imapHost: String,
            isIngestionEnabled: Bool = true,
            linkedAt: Date = .now
        ) {
            self.id = id
            self.kind = kind
            self.emailAddress = emailAddress
            self.imapHost = imapHost
            self.isIngestionEnabled = isIngestionEnabled
            self.linkedAt = linkedAt
        }

        var displayLabel: String { emailAddress }
    }

    // MARK: - Storage keys (legacy + registry)

    private static let service = "com.ratiovita.secure-ingestion-vault"
    private static let connectedKey = "com.ratiovita.ingestion.connectedProviders"
    private static let inboxRegistryKey = "com.ratiovita.ingestion.secureInboxRegistry"
    private static let legacyIMAPHostKey = "com.ratiovita.ingestion.imapHost"
    private static let legacyIMAPUserKey = "com.ratiovita.ingestion.imapUser"

    // MARK: - OAuth providers (single slot each)

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
    }

    static func saveOAuthPlaceholderToken(for provider: Provider, token: String) throws {
        try saveSecret(token, account: provider.rawValue)
        markConnected(provider)
    }

    // MARK: - Dynamic secure inbox registry

    static func allSecureInboxes() -> [SecureInboxAccount] {
        migrateLegacyIMAPAccountIfNeeded()
        guard
            let data = UserDefaults.standard.data(forKey: inboxRegistryKey),
            let decoded = try? JSONDecoder().decode([SecureInboxAccount].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.linkedAt < $1.linkedAt }
    }

    static func activeSecureInboxes() -> [SecureInboxAccount] {
        allSecureInboxes().filter(\.isIngestionEnabled)
    }

    static func addSecureInbox(
        kind: SecureInboxKind,
        emailAddress: String,
        imapHost: String,
        appPassword: String
    ) throws -> SecureInboxAccount {
        let trimmedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = imapHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedHost.isEmpty, !trimmedPassword.isEmpty else {
            throw VaultError.invalidCredentials
        }

        var accounts = allSecureInboxes()
        if accounts.contains(where: { $0.emailAddress.caseInsensitiveCompare(trimmedEmail) == .orderedSame }) {
            throw VaultError.duplicateInbox
        }

        let account = SecureInboxAccount(
            kind: kind,
            emailAddress: trimmedEmail,
            imapHost: trimmedHost
        )
        try saveSecret(trimmedPassword, account: keychainAccount(for: account.id))
        accounts.append(account)
        try persistInboxRegistry(accounts)
        return account
    }

    static func removeSecureInbox(id: UUID) throws {
        var accounts = allSecureInboxes()
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        try deleteSecret(account: keychainAccount(for: id))
        accounts.remove(at: index)
        try persistInboxRegistry(accounts)
    }

    static func setIngestionEnabled(id: UUID, enabled: Bool) throws {
        var accounts = allSecureInboxes()
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].isIngestionEnabled = enabled
        try persistInboxRegistry(accounts)
    }

    // MARK: - Legacy single-IMAP migration

    private static func migrateLegacyIMAPAccountIfNeeded() {
        guard UserDefaults.standard.data(forKey: inboxRegistryKey) == nil else { return }

        let legacyHost = UserDefaults.standard.string(forKey: legacyIMAPHostKey) ?? ""
        let legacyUser = UserDefaults.standard.string(forKey: legacyIMAPUserKey) ?? ""
        guard !legacyHost.isEmpty, !legacyUser.isEmpty else { return }

        let accountId = UUID()
        let account = SecureInboxAccount(
            id: accountId,
            kind: .customIMAP,
            emailAddress: legacyUser,
            imapHost: legacyHost
        )

        if let legacySecret = try? readSecret(account: ProviderLegacyIMAPAccount) {
            try? saveSecret(legacySecret, account: keychainAccount(for: accountId))
            try? deleteSecret(account: ProviderLegacyIMAPAccount)
        }

        try? persistInboxRegistry([account])
        UserDefaults.standard.removeObject(forKey: legacyIMAPHostKey)
        UserDefaults.standard.removeObject(forKey: legacyIMAPUserKey)

        var ids = connectedProviderIDs()
        ids.remove("customIMAP")
        UserDefaults.standard.set(Array(ids), forKey: connectedKey)
    }

    private static let ProviderLegacyIMAPAccount = "customIMAP"

    // MARK: - Keychain helpers

    private static func keychainAccount(for inboxId: UUID) -> String {
        "secure-inbox-\(inboxId.uuidString)"
    }

    private static func connectedProviderIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: connectedKey) ?? [])
    }

    private static func persistInboxRegistry(_ accounts: [SecureInboxAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        UserDefaults.standard.set(data, forKey: inboxRegistryKey)
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

    private static func readSecret(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw VaultError.secretUnavailable
        }
        return secret
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

    enum VaultError: LocalizedError {
        case invalidCredentials
        case duplicateInbox
        case secretUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidCredentials: "Enter a valid email, IMAP host, and app-specific password."
            case .duplicateInbox: "That inbox is already linked."
            case .secretUnavailable: "Could not read credentials from the secure vault."
            }
        }
    }
}
