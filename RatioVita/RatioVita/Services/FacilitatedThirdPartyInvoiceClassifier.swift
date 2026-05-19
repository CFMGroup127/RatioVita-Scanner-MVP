import Foundation
import SwiftData

/// Flags invoices you generated on behalf of crew (training sandbox — segregated from personal/corporate tax).
enum FacilitatedThirdPartyInvoiceClassifier {
    /// Known crew names from facilitated invoice batches (filename / merchant heuristics).
    static let knownCrewTokens: [String] = [
        "andrei muresan",
        "cheryl louvelle mccain",
        "ciaran wilson",
        "hank martyn",
        "thomas godland",
        "river godland",
        "william engel",
        "garry",
        "cynthia",
        "aiden",
        "neil",
        "darci cheyne",
        "diana ivanova",
        "erin logan",
        "erminia diamantopoulos",
        "marlena kaesler",
        "guadalupe diaz",
        "paul franklin",
        "sany guest",
    ]

    static func classify(receipt: Receipt) -> Bool {
        let corpus = combinedCorpus(for: receipt)
        guard !corpus.isEmpty else { return false }

        if corpus.contains("for ") && knownCrewTokens.contains(where: { corpus.contains($0) }) {
            return true
        }

        if corpus.hasPrefix("for ") || corpus.contains(" for ") {
            for token in knownCrewTokens where corpus.contains(token) {
                return true
            }
        }

        if DocumentTypeOption.fromStored(receipt.documentType) == .outgoingInvoice {
            for token in knownCrewTokens where corpus.contains(token) {
                if !corpus.contains("bespoke"), !corpus.contains("craft and catering") {
                    return true
                }
            }
        }

        return false
    }

    /// Re-scan pending Review rows after bulk import (safe to run repeatedly).
    @MainActor
    static func retagPendingReview(context: ModelContext) -> Int {
        let fd = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.pendingHumanReview && $0.trashedAt == nil }
        )
        let rows = (try? context.fetch(fd)) ?? []
        var tagged = 0
        for receipt in rows {
            let before = receipt.facilitatedThirdPartyLabor
            applyIfNeeded(to: receipt)
            if receipt.facilitatedThirdPartyLabor, !before { tagged += 1 }
        }
        try? context.save()
        return tagged
    }

    static func applyIfNeeded(to receipt: Receipt) {
        let flagged = classify(receipt: receipt)
        guard flagged != receipt.facilitatedThirdPartyLabor else { return }
        receipt.facilitatedThirdPartyLabor = flagged
        if flagged {
            let lane = "Facilitated third-party labor (crew invoice you issued)"
            if let notes = receipt.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                if !notes.localizedCaseInsensitiveContains("Facilitated third-party") {
                    receipt.notes = "\(notes)\n\(lane)"
                }
            } else {
                receipt.notes = lane
            }
            if receipt.vaultPathPrefix == nil || receipt.vaultPathPrefix?.isEmpty == true {
                receipt.vaultPathPrefix = "Facilitated-Crew-Invoices"
            }
        }
    }

    private static func combinedCorpus(for receipt: Receipt) -> String {
        [
            receipt.merchant,
            receipt.notes,
            receipt.invoiceClientProjectTitle,
            receipt.payeeName,
            receipt.payorName,
            receipt.documentNumber,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }
}
