import Foundation
import SwiftData

/// Shared filing / Arctic Vault orchestration (folder CRUD, merchant rules, audit append).
@MainActor
enum FilingCoordinator {
    static let auditKindFolderCreated = "arctic.folder.created"
    static let auditKindRuleCreated = "merchant.rule.created"
    static let auditKindRuleApplied = "merchant.rule.applied"
    static let auditKindReceiptRefiled = "receipt.refiled"
    static let auditKindReceiptPagesSplit = "receipt.pages_split"
    static let auditKindReceiptExplodeAllPages = "receipt.explode_all_pages"
    static let auditKindReceiptMerged = "receipt.merged_records"
    static let auditKindReceiptExplodeSelectedPages = "receipt.explode_selected_pages"
    static let auditKindSentinelChefFloorApplied = "sentinel.chef.floor_applied"
    static let auditKindSentinelChefTrueEarned = "sentinel.chef.true_earned_higher"
    static let auditKindDealMemoOnboarded = "deal_memo.onboarded"
    static let auditKindInternalInvoicePolarityLock = "receipt.internal_invoice_polarity"
    static let auditKindChequeStubReparse = "receipt.cheque_stub_reparse"
    static let auditKindContactHarvested = "contact.harvested"
    static let auditKindReceiptLineAllocation = "receipt.line_allocation"

    static func appendAudit(
        context: ModelContext,
        kindRaw: String,
        title: String,
        detail: String? = nil
    ) {
        context.insert(SovereignAuditLogEntry(kindRaw: kindRaw, title: title, detail: detail))
    }

    static func insertRootFolder(
        title: String,
        sfSymbolName: String?,
        context: ModelContext
    ) throws -> ArcticVaultFolder {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fd = FetchDescriptor<ArcticVaultFolder>()
        let roots = try context.fetch(fd).filter { $0.parent == nil }
        let nextIndex = (roots.map(\.sortIndex).max() ?? -1) + 1
        let folder = ArcticVaultFolder(title: trimmed, sortIndex: nextIndex, sfSymbolName: sfSymbolName, parent: nil)
        context.insert(folder)
        appendAudit(
            context: context,
            kindRaw: auditKindFolderCreated,
            title: "Arctic folder created",
            detail: folder.canonicalVaultPrefix
        )
        try context.save()
        return folder
    }

    /// Applies the highest-priority enabled `MerchantFilingRule` when the receipt has no manual `vaultPathPrefix`.
    static func applyMerchantFilingRulesIfNeeded(to receipt: Receipt, context: ModelContext) throws {
        if let existing = receipt.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            return
        }
        let fd = FetchDescriptor<MerchantFilingRule>(sortBy: [SortDescriptor(\.priority, order: .reverse)])
        let rules = try context.fetch(fd).filter(\.isEnabled)
        let merchantHaystack = receipt.merchant.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let lines = receipt.lineItems.map {
            $0.lineDescription.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        }

        for rule in rules {
            let needle = rule.merchantContainsNormalized
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
            guard !needle.isEmpty, merchantHaystack.contains(needle) else { continue }

            if let liNeedle = rule.lineItemContainsNormalized?.trimmingCharacters(in: .whitespacesAndNewlines),
               !liNeedle.isEmpty
            {
                let liNorm = liNeedle.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                guard lines.contains(where: { $0.contains(liNorm) }) else { continue }
            }

            let target = rule.targetVaultPathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !target.isEmpty else { continue }
            receipt.vaultPathPrefix = target
            appendAudit(
                context: context,
                kindRaw: auditKindRuleApplied,
                title: "Merchant filing rule applied",
                detail: "mrid:\(rule.id.uuidString);rid:\(receipt.id.uuidString)|\(rule.merchantContainsNormalized) → \(target)"
            )
            return
        }
    }

    static func insertMerchantRule(
        merchantContains: String,
        lineItemContains: String?,
        targetVaultPathPrefix: String,
        context: ModelContext
    ) throws {
        let m = merchantContains.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        let mNorm = m.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let liNorm: String? = {
            guard let raw = lineItemContains?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            return raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        }()
        let target = targetVaultPathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !target.isEmpty else { return }

        let rule = MerchantFilingRule(
            merchantContainsNormalized: mNorm,
            lineItemContainsNormalized: liNorm,
            targetVaultPathPrefix: target,
            priority: 10,
            isEnabled: true
        )
        context.insert(rule)
        appendAudit(
            context: context,
            kindRaw: auditKindRuleCreated,
            title: "Merchant filing rule created",
            detail: "mrid:\(rule.id.uuidString)|\(mNorm) → \(target)"
        )
        try context.save()
    }
}
