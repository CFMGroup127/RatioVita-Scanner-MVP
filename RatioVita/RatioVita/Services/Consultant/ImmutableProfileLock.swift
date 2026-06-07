import Foundation

struct LockedConsultantFields: Codable, Sendable {
    var legalName: String
    var addressLine: String
    var corporateEntityName: String
    var unionTier: String
    var activeProductionTitle: String
    var hourlyRate: Double
    var kitAllowance: Double
}

@MainActor
enum ImmutableProfileLock {
    static func lock(
        profile: ExpertConsultantProfile,
        fields: LockedConsultantFields
    ) {
        guard let data = try? JSONEncoder().encode(fields),
              let json = String(data: data, encoding: .utf8) else { return }
        profile.lockedProfileJSON = json
        profile.activeProductionTitle = fields.activeProductionTitle
        profile.updatedAt = .now
        profile.onboardingStatus = .verifiedAndFlattened
    }

    static func read(profile: ExpertConsultantProfile) -> LockedConsultantFields? {
        guard let data = profile.lockedProfileJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LockedConsultantFields.self, from: data)
    }

    static var fieldsAreEditable: Bool { false }
}
