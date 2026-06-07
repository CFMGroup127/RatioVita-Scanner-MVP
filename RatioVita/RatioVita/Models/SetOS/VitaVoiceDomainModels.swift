import Foundation

enum AudioStreamPriority: Int, Codable, Comparable, Sendable {
    case standardChat = 1
    case tacticalDepartment = 2
    case administrativeWhisper = 3
    case emergencyAlert = 4

    static func < (lhs: AudioStreamPriority, rhs: AudioStreamPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
            case .standardChat: "Standard"
            case .tacticalDepartment: "Tactical"
            case .administrativeWhisper: "Admin whisper"
            case .emergencyAlert: "Emergency"
        }
    }
}

struct ActiveAudioChannel: Identifiable, Codable, Sendable {
    var id: UUID
    var channelName: String
    var boundDomain: MacroTenantDomain
    var minimumRequiredTier: StructuralRankTier
    var isSpatialGeofenced: Bool
    var priority: AudioStreamPriority

    init(
        id: UUID = UUID(),
        channelName: String,
        boundDomain: MacroTenantDomain,
        minimumRequiredTier: StructuralRankTier,
        isSpatialGeofenced: Bool = false,
        priority: AudioStreamPriority = .standardChat
    ) {
        self.id = id
        self.channelName = channelName
        self.boundDomain = boundDomain
        self.minimumRequiredTier = minimumRequiredTier
        self.isSpatialGeofenced = isSpatialGeofenced
        self.priority = priority
    }
}

struct VoicePacket: Identifiable, Sendable {
    let id: UUID
    let senderLabel: String
    let message: String
    let priority: AudioStreamPriority
    let domain: MacroTenantDomain
    let minimumTier: StructuralRankTier
    let channelID: UUID
    let encodedAt: Date
}

struct SpatialVoiceBridge: Identifiable, Sendable {
    let id: UUID
    let operatorLabel: String
    let responderLabel: String
    let incidentSummary: String
    let openedAt: Date
}
