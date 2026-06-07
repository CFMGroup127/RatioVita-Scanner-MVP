import Foundation
import SwiftData

/// Accounts-configured approval routing for timesheets and purchase orders.
@MainActor
enum AccountingProtocolEngine {
    struct RequiredApprovalSteps: Sendable {
        var needsDeptHead: Bool
        var needsPM: Bool
        var needsAccounting: Bool
        var needsExecutive: Bool
    }

    static func fetchOrCreateRules(
        context: ModelContext,
        productionProjectID: UUID?
    ) throws -> ProductionApprovalRule {
        let pid = productionProjectID
        let descriptor = FetchDescriptor<ProductionApprovalRule>()
        let all = try context.fetch(descriptor)
        if let match = all.first(where: { $0.productionProjectID == pid }) {
            applyRuntimeOverrides(to: match)
            return match
        }
        let rule = ProductionApprovalRule(productionProjectID: pid)
        applyRuntimeOverrides(to: rule)
        context.insert(rule)
        try context.save()
        return rule
    }

    static func applyRuntimeOverrides(to rule: ProductionApprovalRule) {
        if let override = UserDefaults.standard.object(forKey: RuntimeConfigKeys.pettyCashOverrideKey) as? Double {
            rule.pettyCashAutoApproveCAD = Decimal(override)
        }
    }

    static func requiredStepsForPurchaseOrder(
        amount: Decimal,
        submittedByRole: String,
        rules: ProductionApprovalRule
    ) -> RequiredApprovalSteps {
        let role = submittedByRole.lowercased()
        let isProducerOrEP = role.contains("producer") || role.contains("executive")
        if amount >= rules.poRequiresExecutiveAboveCAD {
            return RequiredApprovalSteps(
                needsDeptHead: !isProducerOrEP,
                needsPM: true,
                needsAccounting: true,
                needsExecutive: true
            )
        }
        if amount >= rules.poRequiresAccountingAboveCAD {
            return RequiredApprovalSteps(
                needsDeptHead: amount <= rules.poDeptHeadMaxCAD && !isProducerOrEP,
                needsPM: true,
                needsAccounting: true,
                needsExecutive: false
            )
        }
        if amount >= rules.poRequiresPMAboveCAD || isProducerOrEP {
            return RequiredApprovalSteps(
                needsDeptHead: amount <= rules.poDeptHeadMaxCAD && !isProducerOrEP,
                needsPM: true,
                needsAccounting: false,
                needsExecutive: false
            )
        }
        return RequiredApprovalSteps(
            needsDeptHead: true,
            needsPM: false,
            needsAccounting: false,
            needsExecutive: false
        )
    }

    @discardableResult
    static func advancePurchaseOrder(
        po: ProductionPurchaseOrder,
        rules: ProductionApprovalRule,
        signerName: String,
        role: ApprovalSignerRole
    ) -> ApprovalState {
        let steps = requiredStepsForPurchaseOrder(
            amount: po.totalAmountCAD,
            submittedByRole: po.submittedByRole,
            rules: rules
        )
        let now = Date.now
        switch role {
            case .departmentHead where steps.needsDeptHead:
                po.deptHeadSignerName = signerName
                po.deptHeadSignedAt = now
                po.approvalState = .departmentHeadVerified
            case .productionManager where steps.needsPM:
                po.pmSignerName = signerName
                po.pmSignedAt = now
                po.approvalState = .productionManagerAuthorized
            case .accounting where steps.needsAccounting:
                po.accountingSignerName = signerName
                po.accountingSignedAt = now
                po.approvalState = .accountingCleared
            case .executive where steps.needsExecutive:
                po.executiveSignerName = signerName
                po.executiveSignedAt = now
                po.approvalState = .accountingCleared
            default:
                break
        }
        po.updatedAt = now
        if po.approvalState == .accountingCleared
            || (!steps.needsAccounting && !steps.needsExecutive && po.approvalState == .productionManagerAuthorized)
            || (!steps.needsPM && !steps.needsAccounting && po.approvalState == .departmentHeadVerified)
        {
            return po.approvalState
        }
        return po.approvalState
    }

    static func advanceTimesheet(
        day: CrewTimecardDay,
        rules: ProductionApprovalRule,
        signerName: String,
        role: ApprovalSignerRole
    ) {
        let now = Date.now
        switch role {
            case .departmentHead where rules.timesheetRequiresDeptHead:
                day.deptHeadSignerInitials = signerName
                day.deptHeadSignerName = signerName
                day.deptHeadSignedAt = now
                day.approvalState = .departmentHeadVerified
            case .productionManager where rules.timesheetRequiresPM:
                day.pmSignerInitials = signerName
                day.pmSignerName = signerName
                day.pmSignedAt = now
                day.approvalState = .productionManagerAuthorized
            case .accounting where rules.timesheetRequiresAccounting:
                day.accountingSignerInitials = signerName
                day.accountingSignerName = signerName
                day.accountingSignedAt = now
                day.approvalState = .accountingCleared
            default:
                break
        }
        day.updatedAt = now
    }

    enum ApprovalSignerRole: String, Sendable {
        case departmentHead
        case productionManager
        case accounting
        case executive
    }
}
