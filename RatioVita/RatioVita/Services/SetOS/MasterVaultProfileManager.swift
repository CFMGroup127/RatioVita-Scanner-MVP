import Combine
import Foundation

/// Single-app persona morph — radio-button hat + guild switching (Sprint DDDD / EEEE).
@MainActor
final class MasterVaultProfileManager: ObservableObject {
    static let shared = MasterVaultProfileManager()

    @Published private(set) var personas: [UserPersonaProfile] = []
    @Published var activePersonaID: UUID?
    @Published var activeMacroDomain: MacroTenantDomain = .technicalCrews

    private init() {
        personas = Self.defaultPersonas
        activePersonaID = personas.first?.id
        if let raw = UserDefaults.standard.string(forKey: Keys.macroDomain),
           let domain = MacroTenantDomain(rawValue: raw)
        {
            activeMacroDomain = domain
        }
        if let idRaw = UserDefaults.standard.string(forKey: Keys.personaID),
           let id = UUID(uuidString: idRaw)
        {
            activePersonaID = id
        }
        Task { @MainActor in
            self.applyActivePersonaToSession()
        }
    }

    var activePersona: UserPersonaProfile? {
        guard let activePersonaID else { return personas.first }
        return personas.first { $0.id == activePersonaID } ?? personas.first
    }

    func selectPersona(_ profile: UserPersonaProfile) {
        VitaVoiceAudioManager.shared.cutAllStreamsForPersonaShift()
        activePersonaID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Keys.personaID)
        Task { @MainActor in
            self.applyActivePersonaToSession()
            VitaVoiceAudioManager.shared.refreshSubscriptions()
        }
    }

    func selectMacroDomain(_ domain: MacroTenantDomain) {
        VitaVoiceAudioManager.shared.cutAllStreamsForPersonaShift()
        activeMacroDomain = domain
        UserDefaults.standard.set(domain.rawValue, forKey: Keys.macroDomain)
        VitaVoiceAudioManager.shared.refreshSubscriptions()
    }

    private func applyActivePersonaToSession() {
        guard let persona = activePersona else { return }
        let session = ConsultantSessionManager.shared
        session.setOperationalHat(persona.operationalHat)
    }

    private static let defaultPersonas: [UserPersonaProfile] = [
        UserPersonaProfile(
            assignedGuild: .iatse873,
            positionTitle: "On-show driver",
            rankTier: .fieldCrew,
            departmentCategory: "TRANSPORT",
            operationalHat: .driver
        ),
        UserPersonaProfile(
            assignedGuild: .iatse873,
            positionTitle: "Transport captain",
            rankTier: .departmentHead,
            departmentCategory: "TRANSPORT",
            operationalHat: .captain
        ),
        UserPersonaProfile(
            assignedGuild: .iatse873,
            positionTitle: "Transport coordinator",
            rankTier: .administrative,
            departmentCategory: "TRANSPORT",
            operationalHat: .coordinator
        ),
        UserPersonaProfile(
            assignedGuild: .iatse873,
            positionTitle: "Picture car coordinator",
            rankTier: .departmentHead,
            departmentCategory: "TRANSPORT",
            operationalHat: .pictureCar
        ),
        UserPersonaProfile(
            assignedGuild: .iatse667,
            positionTitle: "1st AC · Focus puller",
            rankTier: .departmentHead,
            departmentCategory: "CAMERA",
            operationalHat: .setSupervisor
        ),
        UserPersonaProfile(
            assignedGuild: .iatse667,
            positionTitle: "2nd AC · Loader",
            rankTier: .fieldCrew,
            departmentCategory: "CAMERA",
            operationalHat: .driver
        ),
        UserPersonaProfile(
            assignedGuild: .dgc,
            positionTitle: "Production manager",
            rankTier: .administrative,
            departmentCategory: "OFFICE",
            operationalHat: .productionManager
        ),
        UserPersonaProfile(
            assignedGuild: .iatse411,
            positionTitle: "Production coordinator",
            rankTier: .administrative,
            departmentCategory: "OFFICE",
            operationalHat: .coordinator
        ),
        UserPersonaProfile(
            assignedGuild: .actra,
            positionTitle: "Talent agent (read-only)",
            rankTier: .administrative,
            departmentCategory: "ACTRA",
            operationalHat: .castProducerDriver
        ),
        UserPersonaProfile(
            assignedGuild: .mobileCraft,
            positionTitle: "Mobile kitchen fleet lead",
            rankTier: .departmentHead,
            departmentCategory: "CULINARY",
            operationalHat: .coCaptain
        ),
        UserPersonaProfile(
            assignedGuild: .vitalogic,
            positionTitle: "VitaLogic platform admin",
            rankTier: .administrative,
            departmentCategory: "PLATFORM",
            operationalHat: .showRunner
        ),
    ]

    private enum Keys {
        static let personaID = "com.ratiovita.vault.activePersonaID"
        static let macroDomain = "com.ratiovita.vault.macroDomain"
    }
}
