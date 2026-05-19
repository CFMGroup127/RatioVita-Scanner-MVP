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
        let (merged, source) = await ReceiptStructuredExtractor.extractMerged(
            combinedOCRText: combinedOCRText,
            heuristic: heuristic,
            registryEntityLegalNames: entityNames
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
                try context.save()
            } catch {
                #if DEBUG
                print("RatioVita: Gemini background refinement failed: \(error.localizedDescription)")
                #endif
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
