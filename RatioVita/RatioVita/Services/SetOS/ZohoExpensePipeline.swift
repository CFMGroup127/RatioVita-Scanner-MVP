import Foundation

/// Telemetry-driven expense + fringe push to Zoho Books (Sprint GGGG).
enum ZohoExpensePipeline {
    struct ExpenseSubmission: Sendable {
        var departmentCode: String
        var amountCents: Int
        var fringeMultiplier: Double
        var narrative: String
        var sourceToken: String
    }

    static func submitFuelVoucher(
        driverToken: String,
        amountCents: Int,
        department: IndustryDepartmentScope = .transport
    ) {
        let fringe = fringeMultiplier(department: department, isTalent: false)
        let submission = ExpenseSubmission(
            departmentCode: department.rawValue,
            amountCents: amountCents,
            fringeMultiplier: fringe,
            narrative: "Fuel voucher · \(driverToken)",
            sourceToken: driverToken
        )
        push(submission)
    }

    static func submitRentalApproval(
        department: IndustryDepartmentScope,
        assetLabel: String,
        amountCents: Int
    ) {
        let submission = ExpenseSubmission(
            departmentCode: department.rawValue,
            amountCents: amountCents,
            fringeMultiplier: fringeMultiplier(department: department, isTalent: false),
            narrative: "Rental · \(assetLabel)",
            sourceToken: assetLabel
        )
        push(submission)
    }

    static func fringeMultiplier(department: IndustryDepartmentScope, isTalent: Bool) -> Double {
        if isTalent { return 1.18 }
        switch department {
            case .transport: return 1.12
            case .costume, .artSetDec: return 1.10
            case .cameraDIT: return 1.14
            default: return 1.08
        }
    }

    private static func push(_ submission: ExpenseSubmission) {
        let gross = Int(Double(submission.amountCents) * submission.fringeMultiplier)
        ZohoEcosystemOrchestrator.shared.enqueue(
            module: .booksExpense,
            payload: [
                "department": submission.departmentCode,
                "amount_cents": "\(submission.amountCents)",
                "gross_cents": "\(gross)",
                "fringe": String(format: "%.2f", submission.fringeMultiplier),
                "narrative": submission.narrative,
                "source": submission.sourceToken,
            ]
        )
    }
}
