import SwiftData
import SwiftUI

/// Detail destination for `NavigationStack` paths keyed by invoice `id`.
struct InvoiceDetailByIDView: View {
    let invoiceID: UUID

    @Query private var matches: [Invoice]

    init(invoiceID: UUID) {
        self.invoiceID = invoiceID
        _matches = Query(
            filter: #Predicate<Invoice> { $0.id == invoiceID },
            sort: \Invoice.issueDate
        )
    }

    var body: some View {
        Group {
            if let invoice = matches.first {
                InvoiceDetailView(invoice: invoice)
                    .id(invoice.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Missing invoice",
                    systemImage: "doc.questionmark",
                    description: Text("This invoice may have been deleted or is still syncing.")
                )
            }
        }
    }
}
