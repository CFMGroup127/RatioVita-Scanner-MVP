import Foundation

/// Role- and tenant-insulated voice channel catalog (Sprint FFFF).
enum AudioChannelMatrix {
    static let catalog: [ActiveAudioChannel] = [
        ActiveAudioChannel(
            channelName: "Technical · Field mesh",
            boundDomain: .technicalCrews,
            minimumRequiredTier: .fieldCrew,
            priority: .standardChat
        ),
        ActiveAudioChannel(
            channelName: "Technical · Dept heads",
            boundDomain: .technicalCrews,
            minimumRequiredTier: .departmentHead,
            priority: .tacticalDepartment
        ),
        ActiveAudioChannel(
            channelName: "Technical · PM whisper",
            boundDomain: .technicalCrews,
            minimumRequiredTier: .departmentHead,
            priority: .administrativeWhisper
        ),
        ActiveAudioChannel(
            channelName: "ACTRA · Agent veil",
            boundDomain: .performerGuilds,
            minimumRequiredTier: .administrative,
            priority: .standardChat
        ),
        ActiveAudioChannel(
            channelName: "Mobile Craft · Kitchen fleet",
            boundDomain: .commercialCulinary,
            minimumRequiredTier: .fieldCrew,
            priority: .tacticalDepartment
        ),
        ActiveAudioChannel(
            channelName: "176 Yonge · Facility ops",
            boundDomain: .realEstateFacility,
            minimumRequiredTier: .departmentHead,
            priority: .tacticalDepartment
        ),
        ActiveAudioChannel(
            channelName: "VitaLogic · Platform core",
            boundDomain: .systemArchitecture,
            minimumRequiredTier: .administrative,
            priority: .administrativeWhisper
        ),
        ActiveAudioChannel(
            channelName: "Spatial · Honeywagon PTT",
            boundDomain: .technicalCrews,
            minimumRequiredTier: .fieldCrew,
            isSpatialGeofenced: true,
            priority: .emergencyAlert
        ),
    ]

    static func subscribedChannels(
        domain: MacroTenantDomain,
        rank: StructuralRankTier
    ) -> [ActiveAudioChannel] {
        catalog.filter { channel in
            channel.boundDomain == domain && rank >= channel.minimumRequiredTier
        }
    }

    static func canReceive(
        packet: VoicePacket,
        listenerDomain: MacroTenantDomain,
        listenerRank: StructuralRankTier
    ) -> Bool {
        guard packet.domain == listenerDomain else { return false }
        return listenerRank >= packet.minimumTier
    }

    static func deliveryRecipients(
        for packet: VoicePacket,
        personas: [UserPersonaProfile]
    ) -> [UserPersonaProfile] {
        personas.filter { persona in
            persona.rankTier >= packet.minimumTier
                && domain(for: persona.assignedGuild) == packet.domain
        }
    }

    static func domain(for guild: ActiveUnionGuild) -> MacroTenantDomain {
        switch guild {
            case .dgc, .iatse411, .iatse873, .iatse667, .nabet700:
                .technicalCrews
            case .actra:
                .performerGuilds
            case .mobileCraft:
                .commercialCulinary
            case .facility176:
                .realEstateFacility
            case .vitalogic:
                .systemArchitecture
        }
    }

    static func whisperChannel(domain: MacroTenantDomain) -> ActiveAudioChannel? {
        catalog.first {
            $0.boundDomain == domain && $0.priority == .administrativeWhisper
        }
    }
}
