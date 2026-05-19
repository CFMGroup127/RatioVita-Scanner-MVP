import Foundation
import SwiftData

/// Immutable audit row when a **production project** is permanently removed (rare; prefer **retired** status).
@Model
final class ProductionProjectDeletionTombstone {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var removedProjectID: UUID
    var titleSnapshot: String
    var parentBusinessSnapshot: String?
    var linkedReceiptCount: Int
    var linkedWorkSessionCount: Int
    var reason: String
    var authorizedBy: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        removedProjectID: UUID,
        titleSnapshot: String,
        parentBusinessSnapshot: String? = nil,
        linkedReceiptCount: Int,
        linkedWorkSessionCount: Int,
        reason: String,
        authorizedBy: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.removedProjectID = removedProjectID
        self.titleSnapshot = titleSnapshot
        self.parentBusinessSnapshot = parentBusinessSnapshot
        self.linkedReceiptCount = linkedReceiptCount
        self.linkedWorkSessionCount = linkedWorkSessionCount
        self.reason = reason
        self.authorizedBy = authorizedBy
    }
}
