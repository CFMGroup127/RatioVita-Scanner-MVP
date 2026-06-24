import Foundation

/// Privacy compartment for sovereign identity sharing on set.
enum SovereignPrivacyTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case logisticalOnly = "LogisticalOnly"
    case peerToPeer = "PeerToPeer"
    case circleOfTrust = "CircleOfTrust"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logisticalOnly: "Logistical only"
        case .peerToPeer: "Peer-to-peer"
        case .circleOfTrust: "Circle of trust"
        }
    }

    var subtitle: String {
        switch self {
        case .logisticalOnly:
            "Routing token, obfuscated email — accounting, deal memos, EP Hub."
        case .peerToPeer:
            "Name, department, union status — crew references, day players."
        case .circleOfTrust:
            "Direct phone, email, socials — close department colleagues."
        }
    }
}

/// Compact onboarding payload embedded in QR codes and short serial tokens.
struct SovereignOnboardingTokenPayload: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    var spid: String
    var productionPUID: String?
    var legalName: String
    var guildNumber: String?
    var department: String?
    var unionStatus: String?
    var loanOutEntity: String?
    var routingEmail: String
    var shareTier: SovereignPrivacyTier
    var issuedAt: Date
    var expiresAt: Date
    var publicKeyBase64: String
    var signatureBase64: String

    init(
        version: Int = Self.currentVersion,
        spid: String,
        productionPUID: String? = nil,
        legalName: String,
        guildNumber: String? = nil,
        department: String? = nil,
        unionStatus: String? = nil,
        loanOutEntity: String? = nil,
        routingEmail: String,
        shareTier: SovereignPrivacyTier,
        issuedAt: Date = .now,
        expiresAt: Date,
        publicKeyBase64: String,
        signatureBase64: String
    ) {
        self.version = version
        self.spid = spid
        self.productionPUID = productionPUID
        self.legalName = legalName
        self.guildNumber = guildNumber
        self.department = department
        self.unionStatus = unionStatus
        self.loanOutEntity = loanOutEntity
        self.routingEmail = routingEmail
        self.shareTier = shareTier
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.publicKeyBase64 = publicKeyBase64
        self.signatureBase64 = signatureBase64
    }

    /// Canonical JSON bytes signed by the user's device key (excludes signature field).
    func canonicalSigningBytes() throws -> Data {
        var copy = self
        copy.signatureBase64 = ""
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(copy)
    }
}

/// Masked professional fields exposed per privacy tier.
struct SovereignMaskedIdentity: Sendable {
    let spid: String
    let displayName: String
    let routingEmail: String?
    let guildNumber: String?
    let department: String?
    let unionStatus: String?
    let loanOutEntity: String?
    let directPhone: String?
    let directEmail: String?
    let shareTier: SovereignPrivacyTier
}
