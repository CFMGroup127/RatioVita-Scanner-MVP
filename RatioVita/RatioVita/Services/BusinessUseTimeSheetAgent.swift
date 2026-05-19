import Foundation
import SwiftData

/// Sprint E forensic pass: align receipt calendar days with `WorkRecord` rows for the same `ProductionProject`.
@MainActor
enum BusinessUseTimeSheetAgent {
    static func applyTimeSheetAnchors(modelContext: ModelContext) throws {
        let records = try modelContext.fetch(FetchDescriptor<WorkRecord>())
        guard !records.isEmpty else { return }

        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>())
        let calendar = Calendar.current
        func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

        for receipt in receipts {
            guard receipt.trashedAt == nil else { continue }
            switch DocumentTypeOption.fromStored(receipt.documentType) {
                case .incomeOrCheck, .paycheck, .canadianTaxSlip:
                    continue
                default:
                    break
            }
            guard let project = receipt.productionProject else { continue }
            let anchor = receipt.transactionDate ?? receipt.createdAt
            let day = startOfDay(anchor)
            let matched = records.contains { rec in
                startOfDay(rec.workDate) == day && rec.productionProject?.id == project.id
            }
            if matched {
                receipt.businessUseSuggestedPercent = 100
                receipt.businessUsePercent = 100
                receipt.businessUseVerifiedByTimeSheet = true
            }
        }
    }
}
