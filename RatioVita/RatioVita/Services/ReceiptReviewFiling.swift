import Foundation
import SwiftData

/// Shared Review-queue filing (list bulk actions + receipt detail accept).
@MainActor
enum ReceiptReviewFiling {
    static func applyFile(to receipt: Receipt) {
        receipt.filingCabinetKindRaw = ReceiptCabinetRouting.suggestedCabinetKindRaw(
            taxCategory: receipt.taxCategory,
            merchant: receipt.merchant,
            productionType: receipt.productionType
        )
        ReceiptWorkspaceBatchGuard.clearPinOnFile(receipt)
        receipt.pendingHumanReview = false
        receipt.reviewChecklistDone = false
    }

    static func fileAndSave(
        _ receipt: Receipt,
        context: ModelContext,
        mirrorScannedToPhotoLibrary: Bool
    ) async throws {
        applyFile(to: receipt)
        try ModelContextMainActorSave.saveThrows(context)
        if mirrorScannedToPhotoLibrary, receipt.scannedViaCamera {
            await ReceiptPhotosLibraryExporter.mirrorSavedReceipt(receipt)
        }
    }
}
