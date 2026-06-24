import CryptoKit
import Foundation

/// Hide-my-email style routing proxies and tiered field masking.
enum PrivacyShieldEngine {
    static func routingEmail(for token: String) -> String {
        let sanitized = token
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let hash = SHA256.hash(data: Data(sanitized.utf8))
        let local = hash.prefix(6).map { String(format: "%02x", $0) }.joined()
        return "\(local)@relay.ratiovita.local"
    }

    static func newRoutingProxyToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    static func mask(profile: SovereignProfile, tier: SovereignPrivacyTier) -> SovereignMaskedIdentity {
        switch tier {
        case .logisticalOnly:
            return SovereignMaskedIdentity(
                spid: profile.userSPID,
                displayName: profile.legalName,
                routingEmail: profile.obfuscatedRoutingEmail,
                guildNumber: profile.guildNumber.isEmpty ? nil : profile.guildNumber,
                department: nil,
                unionStatus: nil,
                loanOutEntity: profile.loanOutEntity.isEmpty ? nil : profile.loanOutEntity,
                directPhone: nil,
                directEmail: nil,
                shareTier: tier
            )
        case .peerToPeer:
            return SovereignMaskedIdentity(
                spid: profile.userSPID,
                displayName: profile.legalName,
                routingEmail: profile.obfuscatedRoutingEmail,
                guildNumber: profile.guildNumber.isEmpty ? nil : profile.guildNumber,
                department: profile.department.isEmpty ? nil : profile.department,
                unionStatus: profile.unionStatus.isEmpty ? nil : profile.unionStatus,
                loanOutEntity: nil,
                directPhone: nil,
                directEmail: nil,
                shareTier: tier
            )
        case .circleOfTrust:
            return SovereignMaskedIdentity(
                spid: profile.userSPID,
                displayName: profile.legalName,
                routingEmail: profile.directEmail.isEmpty ? profile.obfuscatedRoutingEmail : profile.directEmail,
                guildNumber: profile.guildNumber.isEmpty ? nil : profile.guildNumber,
                department: profile.department.isEmpty ? nil : profile.department,
                unionStatus: profile.unionStatus.isEmpty ? nil : profile.unionStatus,
                loanOutEntity: profile.loanOutEntity.isEmpty ? nil : profile.loanOutEntity,
                directPhone: profile.directPhone.isEmpty ? nil : profile.directPhone,
                directEmail: profile.directEmail.isEmpty ? nil : profile.directEmail,
                shareTier: tier
            )
        }
    }

    /// Returns true when both parties have mutually elevated to circle of trust.
    static func allowsSocialExchange(localTier: SovereignPrivacyTier, remoteTier: SovereignPrivacyTier) -> Bool {
        localTier == .circleOfTrust && remoteTier == .circleOfTrust
    }
}
