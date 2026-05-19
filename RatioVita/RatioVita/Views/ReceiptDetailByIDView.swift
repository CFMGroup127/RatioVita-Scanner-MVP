import SwiftData
import SwiftUI

/// Detail destination for `NavigationStack` paths keyed by receipt `id`.
struct ReceiptDetailByIDView: View {
    let receiptID: UUID

    @Query private var matches: [Receipt]

    init(receiptID: UUID) {
        self.receiptID = receiptID
        _matches = Query(
            filter: #Predicate<Receipt> { $0.id == receiptID },
            sort: \Receipt.createdAt
        )
    }

    var body: some View {
        Group {
            if let receipt = matches.first {
                ReceiptDetailPlatformView(receipt: receipt)
                    .id(receipt.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Missing receipt",
                    systemImage: "doc.questionmark",
                    description: Text("This item may have been deleted or is still syncing.")
                )
            }
        }
    }
}
