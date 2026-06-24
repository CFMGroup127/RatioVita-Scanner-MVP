import CryptoKit
import Foundation

/// Packages professional identity into signed QR / short-serial onboarding tokens.
enum OnboardingTokenGenerator {
    private static let defaultTTL: TimeInterval = 86_400

    static func generate(
        profile: SovereignProfile,
        privateKey: Curve25519.Signing.PrivateKey,
        productionPUID: String? = nil,
        shareTier: SovereignPrivacyTier? = nil,
        ttl: TimeInterval = defaultTTL
    ) throws -> SovereignOnboardingTokenPayload {
        let tier = shareTier ?? profile.defaultShareTier
        let issuedAt = Date()
        let expiresAt = issuedAt.addingTimeInterval(ttl)
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()

        var payload = SovereignOnboardingTokenPayload(
            spid: profile.userSPID,
            productionPUID: productionPUID,
            legalName: profile.legalName,
            guildNumber: profile.guildNumber.isEmpty ? nil : profile.guildNumber,
            department: profile.department.isEmpty ? nil : profile.department,
            unionStatus: profile.unionStatus.isEmpty ? nil : profile.unionStatus,
            loanOutEntity: profile.loanOutEntity.isEmpty ? nil : profile.loanOutEntity,
            routingEmail: PrivacyShieldEngine.mask(profile: profile, tier: tier).routingEmail ?? profile.obfuscatedRoutingEmail,
            shareTier: tier,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            publicKeyBase64: publicKeyBase64,
            signatureBase64: ""
        )

        let signingBytes = try payload.canonicalSigningBytes()
        let signature = try privateKey.signature(for: signingBytes)
        payload.signatureBase64 = signature.base64EncodedString()
        return payload
    }

    static func encodeForQR(_ payload: SovereignOnboardingTokenPayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return "RVSOV1:" + data.base64EncodedString()
    }

    static func decodeFromQR(_ raw: String) throws -> SovereignOnboardingTokenPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("RVSOV1:") else {
            throw TokenError.invalidPrefix
        }
        let b64 = String(trimmed.dropFirst("RVSOV1:".count))
        guard let data = Data(base64Encoded: b64) else { throw TokenError.invalidEncoding }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SovereignOnboardingTokenPayload.self, from: data)
    }

    static func shortSerial(for payload: SovereignOnboardingTokenPayload) -> String {
        SovereignIdentifierService.shortTransactionSerial(from: payload.spid + payload.issuedAt.ISO8601Format())
    }

    static func verify(_ payload: SovereignOnboardingTokenPayload) throws -> Bool {
        guard payload.version == SovereignOnboardingTokenPayload.currentVersion else {
            throw TokenError.unsupportedVersion
        }
        guard payload.expiresAt > Date() else { throw TokenError.expired }
        guard let pubData = Data(base64Encoded: payload.publicKeyBase64),
              let signatureData = Data(base64Encoded: payload.signatureBase64) else {
            throw TokenError.invalidEncoding
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubData)
        let signingBytes = try payload.canonicalSigningBytes()
        return publicKey.isValidSignature(signatureData, for: signingBytes)
    }

    enum TokenError: LocalizedError {
        case invalidPrefix
        case invalidEncoding
        case expired
        case unsupportedVersion
        case invalidSignature

        var errorDescription: String? {
            switch self {
            case .invalidPrefix: return "Not a RatioVita sovereign token."
            case .invalidEncoding: return "Token payload could not be decoded."
            case .expired: return "Onboarding token has expired."
            case .unsupportedVersion: return "Unsupported token version."
            case .invalidSignature: return "Token signature verification failed."
            }
        }
    }
}
