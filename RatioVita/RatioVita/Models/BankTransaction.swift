import Foundation
import SwiftData

/// Imported bank / card posting used by reconciliation agents (document graph **Linked**).
@Model
final class BankTransaction {
    @Attribute(.unique) var id: UUID
    var postedDate: Date
    /// Canonical signed amount: **debits / purchases negative**, **deposits / credits positive** (personal checking).
    var amount: Decimal
    var currencyCode: String
    var memo: String?
    /// Optional stable id from an import file row for deduplication.
    var externalReference: String?

    /// User marked this posting reconciled without linking a receipt (clears it from the “needs attention” queue).
    var manuallyClearedForReconciliation: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Receipt.matchedBankTransaction)
    var matchedReceipt: Receipt?

    var ledgerAccount: LedgerBankAccount?

    init(
        id: UUID = UUID(),
        postedDate: Date,
        amount: Decimal,
        currencyCode: String = ReceiptCurrency.defaultForLocale.code,
        memo: String? = nil,
        externalReference: String? = nil,
        manuallyClearedForReconciliation: Bool = false,
        matchedReceipt: Receipt? = nil,
        ledgerAccount: LedgerBankAccount? = nil
    ) {
        self.id = id
        self.postedDate = postedDate
        self.amount = amount
        self.currencyCode = currencyCode
        self.memo = memo
        self.externalReference = externalReference
        self.manuallyClearedForReconciliation = manuallyClearedForReconciliation
        self.matchedReceipt = matchedReceipt
        self.ledgerAccount = ledgerAccount
    }
}
