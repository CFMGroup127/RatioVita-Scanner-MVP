import Foundation
import SwiftData

/// “Glass box” filing rule: when **merchant** (and optionally **line item** text) matches, new extractions receive
/// `Receipt.vaultPathPrefix` so the Arctic hierarchy stays consistent (e.g. Bell utility vs Bell Media catering).
@Model
final class MerchantFilingRule {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Normalized substring match against `Receipt.merchant` (lowercase, diacritic-insensitive).
    var merchantContainsNormalized: String
    /// When set, at least one `ReceiptLineItem.lineDescription` must contain this (normalized).
    var lineItemContainsNormalized: String?
    /// Target prefix before merchant/year/month (e.g. `Productions/Bell Media`).
    var targetVaultPathPrefix: String
    /// Higher values win when multiple rules match.
    var priority: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        merchantContainsNormalized: String,
        lineItemContainsNormalized: String? = nil,
        targetVaultPathPrefix: String,
        priority: Int = 10,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.merchantContainsNormalized = merchantContainsNormalized
        self.lineItemContainsNormalized = lineItemContainsNormalized
        self.targetVaultPathPrefix = targetVaultPathPrefix
        self.priority = priority
        self.isEnabled = isEnabled
    }
}
