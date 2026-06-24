import Foundation
import SwiftData

/// Applies confirmed atomic line assignments into venture-scoped `SovereignLedgerEntry` rows.
enum LineItemLedgerDisperseEngine {
    struct DisperseResult: Sendable {
        let entriesCreated: Int
        let masterInvoiceID: UUID
    }

    @MainActor
    static func applyAndDisperse(
        manifest: MasterInvoiceManifest,
        context: ModelContext,
        bookkeepingPassID: String = UUID().uuidString
    ) async throws -> DisperseResult {
        guard manifest.allLinesAssigned else {
            throw LineItemLedgerDisperseError.incompleteAssignments
        }

        var created = 0
        for line in manifest.atomicLineItems.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            guard let target = line.assignedLedgerTarget else { continue }

            let entry = SovereignLedgerEntry(
                entryKind: .expense,
                vendorName: manifest.vendorName,
                grossAmount: line.totalLineAmount,
                currencyCode: manifest.currencyCode,
                transactionTimestamp: manifest.transactionDate,
                lineItemSummary: line.itemDescription,
                ventureEntityID: target.ventureEntityID,
                taxCategory: line.agentSuggestedCategory.displayLabel,
                sourceReceiptID: manifest.sourceReceipt?.id,
                sourceMasterInvoiceID: manifest.id,
                sourceAtomicLineItemID: line.id
            )
            context.insert(entry)
            created += 1
        }

        manifest.refreshReconciledFlag()
        await Task.yield()
        try ModelContextMainActorSave.saveThrows(context)
        return DisperseResult(entriesCreated: created, masterInvoiceID: manifest.id)
    }
}

enum LineItemLedgerDisperseError: LocalizedError {
    case incompleteAssignments

    var errorDescription: String? {
        switch self {
        case .incompleteAssignments:
            "Assign a ledger target to every line item before dispersing."
        }
    }
}
