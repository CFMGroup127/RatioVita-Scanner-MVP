import Foundation
import SwiftData

/// Lightweight append-only audit for **filing** actions (CRA-oriented provenance for how receipts were routed).
@Model
final class SovereignAuditLogEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Stable machine key, e.g. `arctic.folder.created`, `merchant.rule.created`, `receipt.rule_applied`.
    var kindRaw: String
    var title: String
    var detail: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kindRaw: String,
        title: String,
        detail: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kindRaw = kindRaw
        self.title = title
        self.detail = detail
    }
}
