import Foundation
import SwiftData

/// Routes consultants to department-isolated module surfaces only.
@MainActor
enum ConsultantIngestionManager {
    static func allowedSidebarTitles(for department: IndustryDepartmentScope) -> [String] {
        switch department {
            case .transport:
                ["Shuttle tracker", "Fleet monitor", "Comms pager", "Timecard", "Expert program"]
            case .cameraDIT:
                ["Comms pager", "Timecard", "Expert program", "Media Core"]
            case .accounting:
                ["Dispatch & approvals", "Expert program", "AP payroll"]
            case .costume, .tadAD:
                ["Costume console", "TAD logistics", "Timecard", "Expert program"]
            case .artSetDec, .culinaryCraft:
                ["Field ops", "Timecard", "Expert program"]
            case .locations:
                ["Locations desk", "Cube truck gate", "Executive matrix", "Timecard", "Expert program"]
        }
    }

    static func canAccessMasterLedger(profile: ExpertConsultantProfile?) -> Bool {
        profile?.tier == .accountingVault || profile?.department == .accounting
    }

    @discardableResult
    static func seedCoordinatorProfile(
        context: ModelContext,
        department: IndustryDepartmentScope,
        productionTitle: String
    ) throws -> ExpertConsultantProfile {
        let profile = ExpertConsultantProfile(
            department: department,
            tier: .departmentHead,
            yearsOfExperience: 30,
            activeProductionTitle: productionTitle,
            inviteAllocationRemaining: 3
        )
        context.insert(profile)
        try context.save()
        return profile
    }
}
