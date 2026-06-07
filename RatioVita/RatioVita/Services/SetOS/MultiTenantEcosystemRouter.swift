import Foundation

/// Insulates data environments across guild / commercial / platform tenants (Sprint EEEE).
@MainActor
enum MultiTenantEcosystemRouter {
    static func allowedSurfaces(for domain: MacroTenantDomain) -> Set<PerspectiveMaskingEngine.ConsoleSurface> {
        switch domain {
            case .technicalCrews:
                Set(PerspectiveMaskingEngine.ConsoleSurface.allCases)
            case .performerGuilds:
                [.firstLooksCapture, .payrollVault]
            case .commercialCulinary:
                [.fleetMacroGrid, .locationsGreenZones]
            case .realEstateFacility:
                [.locationsGreenZones, .pmShowrunnerMatrix]
            case .systemArchitecture:
                Set(PerspectiveMaskingEngine.ConsoleSurface.allCases)
        }
    }

    static func ingestPerformerVoucher(actorToken: String, wrapTimestamp: Date) -> String {
        "ACTRA voucher queued · \(actorToken) · wrap \(wrapTimestamp.formatted(date: .omitted, time: .shortened))"
    }

    static func agentReadOnlyStatus(clientToken: String) -> String {
        "Agent veil · transport + call for \(clientToken)"
    }
}
