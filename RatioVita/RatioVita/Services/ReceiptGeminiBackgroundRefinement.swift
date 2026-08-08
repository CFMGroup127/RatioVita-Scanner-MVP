import Foundation
import SwiftData
import SwiftUI

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// After a **fast** camera save (heuristic-only), runs Gemini `extractMerged` off the hot path so multi-device
/// workflows see a row immediately while Flash-Lite refinement lands shortly after (default model:
/// `GeminiAPIKeyResolver.defaultGeminiModelId`).
enum ReceiptGeminiBackgroundRefinement {
    /// Schedules refinement without blocking the scan completion handler.
    static func scheduleAfterQuickCameraSave(
        container: ModelContainer,
        receiptID: UUID,
        combinedOCRText: String
    ) {
        let ocrSnapshot = String(combinedOCRText)
        Task.detached(priority: .utility) {
            await run(container: container, receiptID: receiptID, combinedOCRText: ocrSnapshot)
        }
    }

    private static func run(container: ModelContainer, receiptID: UUID, combinedOCRText: String) async {
        #if canImport(UIKit) && !os(watchOS)
        let bgTask = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "RatioVita.GeminiRefine") {}
        }
        #endif

        let heuristic = OCRParsing.extractData(from: combinedOCRText)
        let entityNames = await MainActor.run {
            let ctx = ModelContext(container)
            return ReceiptPersistence.fetchPolarityEntityLegalNames(context: ctx)
        }
        let activeLedger = await MainActor.run { () -> SovereignLedger? in
            let ctx = ModelContext(container)
            let fd = FetchDescriptor<Receipt>(predicate: #Predicate { $0.id == receiptID })
            if let receipt = try? ctx.fetch(fd).first,
               let frozen = SovereignLedger.fromStored(receipt.captureLedgerContextRaw)
            {
                return frozen
            }
            return SovereignContextManager.shared.activeLedger
        }
        let (merged, source) = await ReceiptStructuredExtractor.extractMerged(
            combinedOCRText: combinedOCRText,
            heuristic: heuristic,
            registryEntityLegalNames: entityNames,
            activeLedger: activeLedger
        )

        await MainActor.run {
            let context = ModelContext(container)
            do {
                try ReceiptPersistence.applyGeminiRefinementProfile(
                    merged: merged,
                    extractionSource: source,
                    receiptID: receiptID,
                    context: context
                )
                try ModelContextMainActorSave.saveThrows(context)
            } catch {
                #if DEBUG
                print("RatioVita: Gemini background refinement failed: \(error.localizedDescription)")
                #endif
                ReceiptPersistence.markGeminiRefinementPersistFailed(receiptID: receiptID, context: context)
                try? ModelContextMainActorSave.saveThrows(context)
            }
        }

        #if canImport(UIKit) && !os(watchOS)
        await MainActor.run {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
        #endif
    }
}
