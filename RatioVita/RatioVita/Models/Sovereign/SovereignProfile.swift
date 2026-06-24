import Foundation
import SwiftData

/// Device-independent sovereign professional identity — SPID, guild, privacy tiers, routing proxies.
@Model
final class SovereignProfile {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var userSPID: String
    var masterIdentityID: UUID?
    var legalName: String
    var guildNumber: String
    var department: String
    var unionStatus: String
    var loanOutEntity: String
    var directEmail: String
    var directPhone: String
    var socialHandlesRaw: String
    var defaultShareTierRaw: String
    var routingProxyToken: String
    var signingPublicKeyBase64: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userSPID: String,
        masterIdentityID: UUID? = nil,
        legalName: String,
        guildNumber: String = "",
        department: String = "",
        unionStatus: String = "",
        loanOutEntity: String = "",
        directEmail: String = "",
        directPhone: String = "",
        socialHandles: [String] = [],
        defaultShareTier: SovereignPrivacyTier = .logisticalOnly,
        routingProxyToken: String = "",
        signingPublicKeyBase64: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userSPID = userSPID
        self.masterIdentityID = masterIdentityID
        self.legalName = legalName
        self.guildNumber = guildNumber
        self.department = department
        self.unionStatus = unionStatus
        self.loanOutEntity = loanOutEntity
        self.directEmail = directEmail
        self.directPhone = directPhone
        socialHandlesRaw = Self.encodeList(socialHandles)
        defaultShareTierRaw = defaultShareTier.rawValue
        self.routingProxyToken = routingProxyToken
        self.signingPublicKeyBase64 = signingPublicKeyBase64
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func encodeList(_ items: [String]) -> String {
        items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "||")
    }

    static func decodeList(_ raw: String) -> [String] {
        raw.split(separator: "||", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension SovereignProfile {
    var socialHandles: [String] {
        get { Self.decodeList(socialHandlesRaw) }
        set { socialHandlesRaw = Self.encodeList(newValue) }
    }

    var defaultShareTier: SovereignPrivacyTier {
        get { SovereignPrivacyTier(rawValue: defaultShareTierRaw) ?? .logisticalOnly }
        set { defaultShareTierRaw = newValue.rawValue }
    }

    var obfuscatedRoutingEmail: String {
        if !routingProxyToken.isEmpty {
            return PrivacyShieldEngine.routingEmail(for: routingProxyToken)
        }
        return PrivacyShieldEngine.routingEmail(for: userSPID)
    }
}
