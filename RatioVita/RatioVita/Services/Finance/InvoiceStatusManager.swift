import Foundation
import SwiftData

/// Maintains outgoing invoice lifecycle flags (e.g. Sent → Overdue when past due).
enum InvoiceStatusManager {
    /// Transitions **Sent** invoices whose due date is before today to **Overdue**.
    @MainActor
    static func updateOverdueStatuses(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Invoice>()

        do {
            let invoices = try modelContext.fetch(descriptor)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            var hasChanges = false

            for invoice in invoices {
                guard invoice.status == .sent else { continue }
                let dueDay = calendar.startOfDay(for: invoice.dueDate)
                guard dueDay < today else { continue }

                invoice.status = .overdue
                hasChanges = true
            }

            if hasChanges {
                try modelContext.save()
            }
        } catch {
            #if DEBUG
            print("RatioVita: failed to evaluate overdue invoices: \(error)")
            #endif
        }
    }
}
