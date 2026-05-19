import SwiftData
import SwiftUI

/// Receipt detail: side-car forensic layout on every platform (macOS uses the richer correction form).
struct ReceiptDetailPlatformView: View {
    let receipt: Receipt

    var body: some View {
        #if os(macOS)
        ReceiptMacReviewView(receipt: receipt)
            .id(receipt.persistentModelID)
        #else
        ReceiptDetailView(receipt: receipt)
            .id(receipt.persistentModelID)
        #endif
    }
}
