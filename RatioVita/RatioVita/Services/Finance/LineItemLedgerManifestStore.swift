import Foundation
import SwiftData

struct MasterInvoiceManifestSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let vendorName: String
    let transactionDate: Date
    let totalAmount: Decimal
    let currencyCode: String
    let storagePath: String
    let isReconciled: Bool
    let lineItemCount: Int
    let assignedLineCount: Int
    let sourceReceiptID: UUID?
}

/// Background manifest reads for Quick-Assign UI — never blocks view transitions.
enum LineItemLedgerManifestStore {
    static func loadSummaries(container: ModelContainer) async -> [MasterInvoiceManifestSummary] {
        await SwiftDataBackgroundReader.perform(container: container, default: []) { context in
            var descriptor = FetchDescriptor<MasterInvoiceManifest>(
                sortBy: [SortDescriptor(\MasterInvoiceManifest.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200
            let manifests = (try? context.fetch(descriptor)) ?? []
            return manifests.map { manifest in
                let lines = manifest.atomicLineItems
                let assigned = lines.filter { $0.assignedLedgerTargetKindRaw != nil }.count
                return MasterInvoiceManifestSummary(
                    id: manifest.id,
                    vendorName: manifest.vendorName,
                    transactionDate: manifest.transactionDate,
                    totalAmount: manifest.totalAmount,
                    currencyCode: manifest.currencyCode,
                    storagePath: manifest.storagePath,
                    isReconciled: manifest.isReconciled,
                    lineItemCount: lines.count,
                    assignedLineCount: assigned,
                    sourceReceiptID: manifest.sourceReceipt?.id
                )
            }
        }
    }

    static func unreconciledCount(container: ModelContainer) async -> Int {
        await SwiftDataBackgroundReader.perform(container: container, default: 0) { context in
            let descriptor = FetchDescriptor<MasterInvoiceManifest>(
                predicate: #Predicate { !$0.isReconciled }
            )
            return (try? context.fetchCount(descriptor)) ?? 0
        }
    }
}
