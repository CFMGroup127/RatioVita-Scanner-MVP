import Foundation
import SwiftData

/// Flags mixed-use imports and determines when triage is complete.
enum CrossEntityTriageEngine {

    static func markImportedFromSecureInbox(
        receipt: Receipt,
        inboxAccount: SecureIngestionVaultStore.SecureInboxAccount
    ) {
        receipt.requiresCrossEntityTriage = true
        receipt.sourceSecureInboxID = inboxAccount.id.uuidString
        receipt.sourceSecureInboxEmail = inboxAccount.emailAddress
        receipt.crossEntityTriagedAt = nil
    }

    static func refreshTriageState(for receipt: Receipt) {
        if isFullyTriaged(receipt) {
            receipt.crossEntityTriagedAt = .now
            receipt.requiresCrossEntityTriage = false
        } else if hasMixedAllocationWork(receipt) {
            receipt.requiresCrossEntityTriage = true
        }
    }

    nonisolated static func needsTriage(_ receipt: Receipt) -> Bool {
        receipt.trashedAt == nil
            && receipt.requiresCrossEntityTriage
            && receipt.crossEntityTriagedAt == nil
    }

    static func isFullyTriaged(_ receipt: Receipt) -> Bool {
        let lines = receipt.lineItems
        guard !lines.isEmpty else {
            return receipt.productionProject != nil || receipt.pendingHumanReview == false
        }
        return lines.allSatisfy { line in
            line.allocationIsPersonal
                || line.allocatedBusinessEntity != nil
                || line.allocatedProductionProject != nil
        }
    }

    static func hasMixedAllocationWork(_ receipt: Receipt) -> Bool {
        let lines = receipt.lineItems
        guard lines.count > 1 else { return receipt.sourceSecureInboxID != nil }
        let routed = lines.filter {
            $0.allocationIsPersonal || $0.allocatedBusinessEntity != nil || $0.allocatedProductionProject != nil
        }
        return routed.count > 0 && routed.count < lines.count
    }

    /// Scans pending receipts linked to secure inboxes and flags mixed orders for triage.
    static func scanLinkedInboxImports(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.trashedAt == nil && $0.pendingHumanReview == true }
        )
        guard let pending = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for receipt in pending {
            if receipt.sourceSecureInboxID != nil || hasMixedAllocationWork(receipt) {
                receipt.requiresCrossEntityTriage = true
                changed = true
            } else if receipt.notes?.lowercased().contains("amazon") == true
                || receipt.merchant.lowercased().contains("amazon")
            {
                receipt.requiresCrossEntityTriage = true
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }
}
