import Foundation
import SwiftData

/// Immutable audit row left when a **verified** receipt is permanently removed (Area 51 / forensic trail).
@Model
final class RecordTombstone {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var originalReceiptID: UUID
    var merchantSummary: String
    var currencyCode: String
    var totalSummary: Decimal
    var documentDate: Date?
    var productionProjectTitle: String?
    /// When the source receipt had a canonical show, keep the id so the production filter still works.
    var productionProjectID: UUID?
    var reason: String
    var authorizedBy: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        originalReceiptID: UUID,
        merchantSummary: String,
        currencyCode: String,
        totalSummary: Decimal,
        documentDate: Date?,
        productionProjectTitle: String? = nil,
        productionProjectID: UUID? = nil,
        reason: String,
        authorizedBy: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originalReceiptID = originalReceiptID
        self.merchantSummary = merchantSummary
        self.currencyCode = currencyCode
        self.totalSummary = totalSummary
        self.documentDate = documentDate
        self.productionProjectTitle = productionProjectTitle
        self.productionProjectID = productionProjectID
        self.reason = reason
        self.authorizedBy = authorizedBy
    }
}

enum ReceiptDeletionError: Error {
    case missingVerifiedDeletionAudit
}

/// Centralized permanent delete so Trash + Detail share tombstone rules.
enum ReceiptPermanentDeletion {
    @MainActor
    static func deletePermanently(
        _ receipt: Receipt,
        modelContext: ModelContext,
        verifiedReason: String?,
        verifiedAuthorizedBy: String?
    ) throws {
        if receipt.isVerified {
            let reason = verifiedReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let actor = verifiedAuthorizedBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !reason.isEmpty, !actor.isEmpty else {
                throw ReceiptDeletionError.missingVerifiedDeletionAudit
            }
            let tomb = RecordTombstone(
                originalReceiptID: receipt.id,
                merchantSummary: receipt.merchant,
                currencyCode: receipt.currencyCode,
                totalSummary: receipt.total,
                documentDate: receipt.transactionDate ?? receipt.createdAt,
                productionProjectTitle: receipt.productionProject?.title,
                productionProjectID: receipt.productionProject?.id,
                reason: reason,
                authorizedBy: actor
            )
            modelContext.insert(tomb)
        }
        modelContext.delete(receipt)
        try modelContext.save()
    }
}
