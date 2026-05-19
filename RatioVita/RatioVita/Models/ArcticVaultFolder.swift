import Foundation
import SwiftData

/// User-created **Arctic Vault** segment (e.g. `Productions`, `Personal`). Receipts reference the canonical path via
/// `Receipt.vaultPathPrefix` (slash-separated, no leading slash).
@Model
final class ArcticVaultFolder {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var sortIndex: Int
    /// Optional SF Symbol name for folder chrome (e.g. `folder.fill.badge.gearshape`).
    var sfSymbolName: String?
    var parent: ArcticVaultFolder?
    @Relationship(deleteRule: .cascade, inverse: \ArcticVaultFolder.parent) var children: [ArcticVaultFolder]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        sortIndex: Int = 0,
        sfSymbolName: String? = nil,
        parent: ArcticVaultFolder? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.sortIndex = sortIndex
        self.sfSymbolName = sfSymbolName
        self.parent = parent
        children = []
    }

    /// Root →leaf segments joined with `/` (no leading slash).
    var canonicalVaultPrefix: String {
        let chain = sequence(first: Optional(self), next: { $0?.parent }).compactMap { $0 }
        return chain.reversed().map(\.title).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }
}
