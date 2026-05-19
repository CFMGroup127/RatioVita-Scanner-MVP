import Foundation
import SwiftData

/// Combines multiple sovereign receipts into one multi-page record (inverse of **split / explode**).
@MainActor
enum ReceiptMergerService {
    enum MergeError: LocalizedError {
        case needsTwoOrMore
        case includesVerifiedReceipt

        var errorDescription: String? {
            switch self {
                case .needsTwoOrMore:
                    "Select at least two receipts to merge."
                case .includesVerifiedReceipt:
                    "Un-verify any Verified receipts before merging them."
            }
        }
    }

    /// Merges `receipts` into the **oldest** (`createdAt`) row; deletes the others after moving pages + links.
    /// Re-runs OCR-backed extraction (`Gemini` when enabled) on the combined text.
    @discardableResult
    static func mergeReceipts(_ receipts: [Receipt], context: ModelContext) async throws -> Receipt {
        let eligible = receipts
            .filter { $0.trashedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard eligible.count >= 2 else {
            throw MergeError.needsTwoOrMore
        }
        guard !eligible.contains(where: \.isVerified) else {
            throw MergeError.includesVerifiedReceipt
        }

        let primary = eligible[0]
        let secondaries = Array(eligible.dropFirst())

        var absorbedIDs: [String] = []
        var foreignHints: [String] = []

        for secondary in secondaries {
            absorbedIDs.append(secondary.id.uuidString)

            if primary.productionProject?.persistentModelID != secondary.productionProject?.persistentModelID {
                let pt = secondary.productionProject?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !pt.isEmpty {
                    foreignHints.append("merged-away receipt \(secondary.id.uuidString.prefix(8))… linked show: \(pt)")
                }
            }

            let primaryVault =
                primary.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if primaryVault.isEmpty,
               let vc = secondary.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines),
               !vc.isEmpty
            {
                primary.vaultPathPrefix = vc
            }

            if primary.counterpartyContact == nil {
                primary.counterpartyContact = secondary.counterpartyContact
            }
            if primary.productionProject == nil {
                primary.productionProject = secondary.productionProject
            }
            if primary.preliminaryBusinessEntity == nil {
                primary.preliminaryBusinessEntity = secondary.preliminaryBusinessEntity
            }
            let primaryDept =
                primary.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if primaryDept.isEmpty,
               let d = secondary.department?.trimmingCharacters(in: .whitespacesAndNewlines),
               !d.isEmpty
            {
                primary.department = d
            }

            if secondary.scannedViaCamera {
                primary.scannedViaCamera = true
            }

            let pn = primary.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sn = secondary.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !sn.isEmpty {
                primary.notes = pn.isEmpty ? sn : "\(pn)\n\n\(sn)"
            }

            let pa = primary.annotations?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sa = secondary.annotations?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !sa.isEmpty {
                primary.annotations = pa.isEmpty ? sa : "\(pa)\n\n\(sa)"
            }

            if let bt = secondary.matchedBankTransaction, primary.matchedBankTransaction == nil {
                primary.matchedBankTransaction = bt
                secondary.matchedBankTransaction = nil
            }

            let movingSessions = secondary.workSessions
            for ws in movingSessions {
                ws.receipt = primary
            }

            let movingRecords = secondary.workRecords
            for wr in movingRecords {
                wr.sourceReceipt = primary
            }

            let movingImages = secondary.images.sorted { $0.pageIndex < $1.pageIndex }
            for img in movingImages {
                img.receipt = primary
            }

            context.delete(secondary)
        }

        let sortedImages = primary.images.sorted { $0.pageIndex < $1.pageIndex }
        for (i, img) in sortedImages.enumerated() {
            img.pageIndex = i
        }

        let mergeHint =
            "[Forensic] Merged \(eligible.count) receipt(s) → \(primary.id.uuidString.prefix(8))…; absorbed: \(absorbedIDs.map { String($0.prefix(8)) + "…" }.joined(separator: ", "))"
        let ann = primary.annotations?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var composed = ann.isEmpty ? mergeHint : "\(ann)\n\(mergeHint)"
        if !foreignHints.isEmpty {
            composed += "\n" + foreignHints.joined(separator: "\n")
        }
        primary.annotations = composed
        primary.reviewChecklistDone = false

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: FilingCoordinator.auditKindReceiptMerged,
            title: "Receipt merge",
            detail: "into:\(primary.id.uuidString);from:\(absorbedIDs.joined(separator: ","))"
        )

        try context.save()

        let ocr = primary.images
            .sorted { $0.pageIndex < $1.pageIndex }
            .compactMap(\.ocrText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let heuristic = OCRParsing.extractData(from: ocr)
        let entityNames = ReceiptPersistence.fetchPolarityEntityLegalNames(context: context)
        let (merged, source) = await ReceiptStructuredExtractor.extractMerged(
            combinedOCRText: ocr,
            heuristic: heuristic,
            registryEntityLegalNames: entityNames
        )
        try ReceiptPersistence.applyGeminiRefinementProfile(
            merged: merged,
            extractionSource: "\(source)_merged",
            receiptID: primary.id,
            context: context
        )
        try context.save()

        if primary.images.count >= 2 {
            try? ReceiptMultiPageStructuralIntegrity.evaluatePersistedReceipt(receipt: primary, context: context)
        }

        return primary
    }
}
