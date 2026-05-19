import Foundation
import SwiftData

/// VitaLogic-style finance layer: **Tax** suggestions on pending receipts and **bank reconciliation** candidates.
@MainActor
enum ReceiptFinanceAgentsService {
    /// Runs tax/GL heuristics on unverified, non-trashed receipts, then bank matching.
    static func runAll(modelContext: ModelContext) throws {
        try runTaxAndGLPass(modelContext: modelContext)
        try BusinessUseTimeSheetAgent.applyTimeSheetAnchors(modelContext: modelContext)
        try runBankReconciliationPass(modelContext: modelContext)
        try modelContext.save()
    }

    // MARK: - Tax / GL agent (Pending = not yet user-verified)

    private static func runTaxAndGLPass(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Receipt>()
        let receipts = try modelContext.fetch(descriptor)
        for receipt in receipts {
            guard receipt.trashedAt == nil, !receipt.isVerified else { continue }

            let corpus = receiptTextCorpus(receipt)
            guard !corpus.isEmpty else { continue }

            if receipt.depositDate == nil, let a = receipt.annotations, !a.isEmpty {
                receipt.depositDate = HandwrittenAnnotationParsing.parseEdepDepositDate(from: a)
            }

            if receipt.taxCategory == nil,
               let tax = ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus)
            {
                receipt.taxCategory = tax
            }

            for line in receipt.lineItems {
                let lineCorpus = "\(corpus) \(line.lineDescription)"
                if line.glCode == nil, let gl = ReceiptFinanceAgentsHeuristics.suggestGLCode(fromCorpus: lineCorpus) {
                    line.glCode = gl
                }
            }
        }
    }

    private static func receiptTextCorpus(_ receipt: Receipt) -> String {
        var parts: [String] = [
            receipt.merchant,
            receipt.notes ?? "",
            receipt.documentKind ?? "",
            receipt.productionType ?? "",
            receipt.productionProject?.title ?? "",
            receipt.department ?? "",
            receipt.vendorAddress ?? "",
            receipt.paymentMethodSummary ?? "",
        ]
        for s in receipt.workSessions {
            parts.append(s.productionTitle ?? "")
            parts.append(s.productionProject?.title ?? "")
            parts.append(s.departmentOrCategory ?? "")
            parts.append(s.notes ?? "")
        }
        for wr in receipt.workRecords {
            parts.append(wr.showTitle ?? "")
            parts.append(wr.notes ?? "")
            parts.append(wr.productionProject?.title ?? "")
        }
        for li in receipt.lineItems {
            parts.append(li.lineDescription)
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bank reconciliation agent

    private static func runBankReconciliationPass(modelContext: ModelContext) throws {
        let txDescriptor = FetchDescriptor<BankTransaction>()
        let transactions = try modelContext.fetch(txDescriptor)
        let unmatched = transactions.filter { $0.matchedReceipt == nil && !$0.manuallyClearedForReconciliation }

        let receiptDescriptor = FetchDescriptor<Receipt>()
        let receipts = try modelContext.fetch(receiptDescriptor)

        let openReceipts = receipts.filter { !$0.isLedgerLinked && $0.trashedAt == nil }
        for tx in unmatched {
            let ranked = BankReconciliationMatcher.rankedMatches(for: tx, openReceipts: openReceipts)
            guard let top = ranked.first,
                  BankReconciliationMatcher.shouldAutoLink(top),
                  let receipt = openReceipts.first(where: { $0.id == top.receiptID }) else { continue }
            tx.matchedReceipt = receipt
            receipt.matchedBankTransaction = tx
            receipt.isLedgerLinked = true
        }
    }
}
