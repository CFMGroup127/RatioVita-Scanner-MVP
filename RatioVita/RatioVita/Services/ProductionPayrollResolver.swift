import Foundation
import SwiftData

/// Merges per-production payroll overrides with the global compliance profile for PDF export.
@MainActor
enum ProductionPayrollResolver {
    struct ExportContext {
        var productionTitle: String
        var productionCompany: String
        var loanoutCompany: String?
        var displayName: String
        var unionName: String
        var unionID: String
        var compliance: PayrollComplianceProfile
        var crewInitialsForExport: String
        var autoStampCrewInitials: Bool
    }

    static func exportContext(
        production: ProductionProject?,
        productionTitle: String,
        globalCompliance: PayrollComplianceProfile
    ) -> ExportContext {
        var compliance = globalCompliance

        if let production {
            if let raw = production.payrollResidencyStatusRaw,
               let tier = PayrollComplianceProfile.ResidencyTier(rawValue: raw)
            {
                compliance.residencyStatus = tier
            }
            if let raw = production.payrollGuildStatusRaw,
               let tier = PayrollComplianceProfile.GuildTier(rawValue: raw)
            {
                compliance.guildStatus = tier
            }
        }

        let prodCo = production?.payrollProductionCompany?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let billing = production?.billingClientCompanyName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let productionCompany: String = {
            if let prodCo, !prodCo.isEmpty { return prodCo }
            if !billing.isEmpty { return billing }
            return ""
        }()

        let loanoutRaw = production?.payrollLoanoutCompany?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let loanout: String? = loanoutRaw.isEmpty ? nil : loanoutRaw

        let union = production?.payrollUnionName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let unionID = production?.payrollUnionID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let crewOverride = production?.payrollCrewInitialsOverride?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let crewInitials: String = {
            if !crewOverride.isEmpty { return crewOverride }
            if !compliance.approvalInitialsCrew.isEmpty { return compliance.approvalInitialsCrew }
            return PayrollComplianceProfileStore.userInitials
        }()

        let autoStamp = production?.payrollAutoStampCrewInitials == true
            || PayrollComplianceProfileStore.autoStampCrewInitials

        if autoStamp, compliance.approvalInitialsCrew.isEmpty, !crewInitials.isEmpty {
            compliance.approvalInitialsCrew = crewInitials
        }

        return ExportContext(
            productionTitle: productionTitle,
            productionCompany: productionCompany,
            loanoutCompany: loanout,
            displayName: InternalIdentityRegistry.payrollDisplayName,
            unionName: union,
            unionID: unionID,
            compliance: compliance,
            crewInitialsForExport: crewInitials,
            autoStampCrewInitials: autoStamp
        )
    }
}
