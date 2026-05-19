import Foundation
import SwiftData

/// Historical or active bank account for deposit-slip matching during migration (e.g. closed CIBC ···7717).
@Model
final class LedgerBankAccount {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var institutionName: String?
    var accountLastFour: String?
    /// Closed accounts still accept mapped deposits without active-balance warnings.
    var isClosed: Bool = false
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \BankTransaction.ledgerAccount)
    var transactions: [BankTransaction]

    @Relationship(deleteRule: .nullify, inverse: \Receipt.ledgerBankAccount)
    var linkedReceipts: [Receipt]

    init(
        id: UUID = UUID(),
        displayName: String,
        institutionName: String? = nil,
        accountLastFour: String? = nil,
        isClosed: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now,
        transactions: [BankTransaction] = [],
        linkedReceipts: [Receipt] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.institutionName = institutionName
        self.accountLastFour = accountLastFour
        self.isClosed = isClosed
        self.notes = notes
        self.createdAt = createdAt
        self.transactions = transactions
        self.linkedReceipts = linkedReceipts
    }
}
