import Foundation
import SwiftData

/// Per-box timecard signatures — initials land in the correct EP approval cell.
@MainActor
enum TimecardApprovalService {
    enum SignatureBox: String, CaseIterable, Sendable {
        case crew = "Crew"
        case departmentHead = "Dept Head"
        case productionManager = "PM"
        case accounting = "Accounting"

        var menuTitle: String { rawValue }
    }

    struct BoxState: Sendable {
        var initials: String?
        var signedAt: Date?
        var isComplete: Bool { initials != nil && signedAt != nil }
    }

    static func boxStates(for day: CrewTimecardDay) -> [SignatureBox: BoxState] {
        [
            .crew: BoxState(initials: day.crewSignerInitials, signedAt: day.crewSignedAt),
            .departmentHead: BoxState(initials: day.deptHeadSignerInitials, signedAt: day.deptHeadSignedAt),
            .productionManager: BoxState(initials: day.pmSignerInitials, signedAt: day.pmSignedAt),
            .accounting: BoxState(initials: day.accountingSignerInitials, signedAt: day.accountingSignedAt),
        ]
    }

    static func initialsForBox(_ box: SignatureBox) -> String {
        let profile = PayrollComplianceProfileStore.profile
        let user = PayrollComplianceProfileStore.userInitials
        switch box {
            case .crew:
                return firstNonEmpty(profile.approvalInitialsCrew, user, suggestedUserInitials())
            case .departmentHead:
                return firstNonEmpty(profile.approvalInitialsDept, user, suggestedUserInitials())
            case .productionManager:
                return firstNonEmpty(profile.approvalInitialsPM, user, suggestedUserInitials())
            case .accounting:
                return firstNonEmpty(
                    profile.approvalInitialsAcct,
                    profile.approvalInitialsProd,
                    user,
                    suggestedUserInitials()
                )
        }
    }

    static func signBox(
        day: CrewTimecardDay,
        box: SignatureBox,
        rules: ProductionApprovalRule,
        context: ModelContext,
        useSavedInitials: Bool = true
    ) throws {
        let stamp = useSavedInitials ? initialsForBox(box) : ""
        guard !stamp.isEmpty else {
            throw TimecardApprovalError.missingInitials(box: box)
        }
        let now = Date.now
        switch box {
            case .crew:
                day.crewSignerInitials = stamp
                day.crewSignedAt = now
            case .departmentHead:
                day.deptHeadSignerInitials = stamp
                day.deptHeadSignedAt = now
                AccountingProtocolEngine.advanceTimesheet(
                    day: day,
                    rules: rules,
                    signerName: stamp,
                    role: .departmentHead
                )
            case .productionManager:
                day.pmSignerInitials = stamp
                day.pmSignedAt = now
                AccountingProtocolEngine.advanceTimesheet(
                    day: day,
                    rules: rules,
                    signerName: stamp,
                    role: .productionManager
                )
            case .accounting:
                day.accountingSignerInitials = stamp
                day.accountingSignedAt = now
                AccountingProtocolEngine.advanceTimesheet(
                    day: day,
                    rules: rules,
                    signerName: stamp,
                    role: .accounting
                )
        }
        refreshClearedState(day: day, rules: rules)
        day.updatedAt = now
        try context.save()
    }

    static func refreshClearedState(day: CrewTimecardDay, rules: ProductionApprovalRule) {
        let crewDone = day.crewSignedAt != nil
        let deptDone = !rules.timesheetRequiresDeptHead || day.deptHeadSignedAt != nil
        let pmDone = !rules.timesheetRequiresPM || day.pmSignedAt != nil
        let acctDone = !rules.timesheetRequiresAccounting || day.accountingSignedAt != nil
        if crewDone, deptDone, pmDone, acctDone {
            day.approvalState = .accountingCleared
        } else if day.pmSignedAt != nil {
            day.approvalState = .productionManagerAuthorized
        } else if day.deptHeadSignedAt != nil {
            day.approvalState = .departmentHeadVerified
        }
    }

    static func nextActionableBox(
        day: CrewTimecardDay,
        rules: ProductionApprovalRule
    ) -> SignatureBox? {
        if day.crewSignedAt == nil { return .crew }
        if rules.timesheetRequiresDeptHead, day.deptHeadSignedAt == nil { return .departmentHead }
        if rules.timesheetRequiresPM, day.pmSignedAt == nil { return .productionManager }
        if rules.timesheetRequiresAccounting, day.accountingSignedAt == nil { return .accounting }
        return nil
    }

    private static func suggestedUserInitials() -> String {
        PayrollComplianceProfileStore.suggestedInitials(
            from: InternalIdentityRegistry.payrollDisplayName.isEmpty
                ? InternalIdentityRegistry.ownerLegalName
                : InternalIdentityRegistry.payrollDisplayName
        )
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        for value in values {
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t.uppercased() }
        }
        return ""
    }

    enum TimecardApprovalError: LocalizedError {
        case missingInitials(box: SignatureBox)

        var errorDescription: String? {
            switch self {
                case let .missingInitials(box):
                    "Add saved initials in Settings → payroll compliance for the \(box.rawValue) box."
            }
        }
    }
}
