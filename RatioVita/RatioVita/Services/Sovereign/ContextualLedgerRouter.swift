import Foundation
import SwiftData

/// Routes ingested receipts to Personal / Venture / Production ledgers; flags conflicts and auto-split.
enum ContextualLedgerRouter {
    struct RoutingOutcome: Sendable {
        var assignedLedger: SovereignLedger?
        var suggestedLedger: SovereignLedger?
        var entityTag: String?
        var entityConfidenceScore: Double?
        var needsSplit: Bool
        var requiresTriage: Bool
        var triageNote: String?
    }

    /// Active hub + optional entity anchors at scan/import time.
    struct ScanContext: Sendable {
        let activeLedger: SovereignLedger
        let productionPUID: String?
        let ventureEntityID: UUID?

        @MainActor
        static func current(modelContext: ModelContext) -> ScanContext {
            let mgr = SovereignContextManager.shared
            let puid: String? = {
                guard let id = mgr.activeProductionID else { return nil }
                let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
                return projects.first(where: { $0.id == id })?.sovereignPUID
            }()
            return ScanContext(
                activeLedger: SovereignLedger(hub: mgr.activeHub),
                productionPUID: puid,
                ventureEntityID: mgr.activeVentureEntityID
            )
        }
    }

    /// Applies routing to a persisted receipt (after line items exist).
    @MainActor
    static func apply(
        to receipt: Receipt,
        merged: ExtractedData,
        combinedOCR: String,
        scanContext: ScanContext,
        modelContext: ModelContext
    ) {
        let outcome = evaluate(
            merged: merged,
            combinedOCR: combinedOCR,
            scanContext: scanContext,
            lineItems: receipt.lineItems
        )

        receipt.captureLedgerContextRaw = scanContext.activeLedger.rawValue

        if let assigned = outcome.assignedLedger {
            receipt.ledgerTypeRaw = assigned.rawValue
        }
        receipt.suggestedLedgerRaw = outcome.suggestedLedger?.rawValue
        receipt.entityConfidenceScore = outcome.entityConfidenceScore
        receipt.entityTag = outcome.entityTag
        receipt.needsSplit = outcome.needsSplit

        if outcome.requiresTriage {
            receipt.requiresCrossEntityTriage = true
            receipt.pendingHumanReview = true
            receipt.crossEntityTriagedAt = nil
            if let note = outcome.triageNote {
                receipt.notes = appendNote(note, to: receipt.notes)
            }
        }

        if outcome.needsSplit {
            receipt.pendingHumanReview = true
        }

        applyProductionProjectHintIfNeeded(
            receipt: receipt,
            merged: merged,
            scanContext: scanContext,
            modelContext: modelContext
        )
        CrossEntityTriageEngine.refreshTriageState(for: receipt)
    }

    static func evaluate(
        merged: ExtractedData,
        combinedOCR: String,
        scanContext: ScanContext,
        lineItems: [ReceiptLineItem]
    ) -> RoutingOutcome {
        let corpus = ledgerCorpus(merged: merged, ocr: combinedOCR)
        let inferred = inferSuggestedLedger(from: corpus, merged: merged)
        let confidence = merged.entityConfidenceScore ?? heuristicConfidence(
            inferred: inferred,
            corpus: corpus,
            merged: merged
        )

        var outcome = RoutingOutcome(
            assignedLedger: nil,
            suggestedLedger: inferred,
            entityTag: entityTag(for: inferred, scanContext: scanContext, merged: merged, corpus: corpus),
            entityConfidenceScore: confidence,
            needsSplit: false,
            requiresTriage: false,
            triageNote: nil
        )

        let lineLedgers = lineItems.compactMap { SovereignLedger.fromStored($0.suggestedLedgerRaw) }
        let uniqueLineLedgers = Set(lineLedgers)

        if uniqueLineLedgers.count > 1 {
            outcome.needsSplit = true
            outcome.requiresTriage = true
            outcome.triageNote =
                "Line items span multiple ledgers — use Split Receipt to assign Personal, Venture, and Production portions."
            return outcome
        }

        if let inferred, inferred != scanContext.activeLedger, confidence >= 0.55 {
            outcome.requiresTriage = true
            outcome.triageNote = triageConflictNote(
                suggested: inferred,
                active: scanContext.activeLedger,
                merchant: merged.merchant
            )
            return outcome
        }

        if let singleLine = uniqueLineLedgers.first, singleLine != scanContext.activeLedger {
            outcome.requiresTriage = true
            outcome.triageNote =
                "Line items suggest \(singleLine.displayName) ledger while you were in \(scanContext.activeLedger.displayName) — please verify."
            return outcome
        }

        outcome.assignedLedger = scanContext.activeLedger
        return outcome
    }

    // MARK: - Heuristics

    private static func inferSuggestedLedger(from corpus: String, merged: ExtractedData) -> SovereignLedger? {
        let lower = corpus.lowercased()

        if ProductionVendorHeuristics.looksLikeProductionExpense(corpus: lower, merged: merged) {
            return .production
        }
        if lower.contains("gst") && lower.contains("rt0001") || lower.contains("business number") {
            return .venture
        }
        if merged.clientProductionCompany != nil
            || merged.clientProjectTitle != nil
            || merged.purchaseOrderNumber != nil
        {
            return .production
        }
        return nil
    }

    private static func heuristicConfidence(
        inferred: SovereignLedger?,
        corpus: String,
        merged: ExtractedData
    ) -> Double {
        guard inferred != nil else { return 0.35 }
        var score = 0.55
        if merged.clientProductionCompany != nil { score += 0.15 }
        if merged.purchaseOrderNumber != nil { score += 0.1 }
        if ProductionVendorHeuristics.looksLikeProductionExpense(corpus: corpus.lowercased(), merged: merged) {
            score += 0.15
        }
        return min(score, 0.98)
    }

    private static func entityTag(
        for ledger: SovereignLedger?,
        scanContext: ScanContext,
        merged: ExtractedData,
        corpus: String
    ) -> String? {
        switch ledger ?? scanContext.activeLedger {
            case .production:
                if let puid = scanContext.productionPUID, !puid.isEmpty { return puid }
                if let po = merged.purchaseOrderNumber, !po.isEmpty { return "PO-\(po)" }
                if let show = merged.clientProjectTitle, !show.isEmpty { return show }
                return ProductionVendorHeuristics.productionCode(in: corpus)
            case .venture:
                return scanContext.ventureEntityID.map { "Venture-\($0.uuidString.prefix(8))" }
            case .personal:
                return "Personal"
        }
    }

    private static func triageConflictNote(
        suggested: SovereignLedger,
        active: SovereignLedger,
        merchant: String?
    ) -> String {
        let vendor = merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "this vendor"
        switch (suggested, active) {
            case (.production, .personal):
                return "Likely Production expense (\(vendor)); please verify ledger — you were in Personal Hub."
            case (.production, .venture):
                return "Likely Production expense (\(vendor)); verify whether this belongs on the show ledger."
            case (.venture, .personal):
                return "Likely Venture / business expense; please verify ledger routing."
            default:
                return "Suggested \(suggested.displayName) ledger differs from active \(active.displayName) context — please verify."
        }
    }

    private static func ledgerCorpus(merged: ExtractedData, ocr: String) -> String {
        [
            merged.merchant,
            merged.payee,
            merged.payor,
            merged.clientProductionCompany,
            merged.clientProjectTitle,
            merged.purchaseOrderNumber,
            ocr,
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private static func applyProductionProjectHintIfNeeded(
        receipt: Receipt,
        merged _: ExtractedData,
        scanContext: ScanContext,
        modelContext: ModelContext
    ) {
        guard scanContext.activeLedger == .production,
              receipt.productionProject == nil,
              let productionID = SovereignContextManager.shared.activeProductionID else { return }
        let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
        if let project = projects.first(where: { $0.id == productionID }) {
            receipt.productionProject = project
        }
    }

    private static func appendNote(_ note: String, to existing: String?) -> String {
        let trimmed = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return note }
        if trimmed.localizedCaseInsensitiveContains(note.prefix(24)) { return trimmed }
        return "\(trimmed)\n\n\(note)"
    }
}

/// Production supplier / craft-services signals shared with Operational Bookkeeper heuristics.
enum ProductionVendorHeuristics {
    private static let productionVendorPatterns = [
        #"(?i)\bsysco\b"#,
        #"(?i)\bgfs\b|\bgordon\s+food"#,
        #"(?i)\bbespoke\s+craft\b|\bbespoke\s+catering\b"#,
        #"(?i)\bcraft\s+services\b"#,
        #"(?i)\bproduction\s+supplies\b"#,
        #"(?i)\bset\s+dec\b|\bset\s+dressing\b"#,
        #"(?i)\bcast\s+&\s+crew\b|\bep\s+financial\b"#,
        #"(?i)\bhome\s+depot\b|\bcanadian\s+tire\b"#,
    ]

    private static let productionCodePattern =
        #"(?i)\b(?:PUID|PROD(?:UCTION)?(?:\s*ID)?|SHOW\s*CODE)\s*[:\-#]?\s*([A-Z0-9][A-Z0-9\-]{2,14})\b"#

    static func looksLikeProductionExpense(corpus lower: String, merged: ExtractedData) -> Bool {
        if productionVendorPatterns.contains(where: { lower.range(of: $0, options: .regularExpression) != nil }) {
            return true
        }
        if lower.contains("crew call") || lower.contains("call sheet") { return true }
        return merged.documentKind?.lowercased().contains("production") == true
    }

    static func productionCode(in corpus: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: productionCodePattern, options: []),
              let m = re.firstMatch(in: corpus, options: [], range: NSRange(corpus.startIndex..., in: corpus)),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: corpus) else { return nil }
        return String(corpus[r])
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
