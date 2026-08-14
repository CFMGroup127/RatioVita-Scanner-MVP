import Foundation
import SwiftData

@Model
final class PaymentRecord {
    @Attribute(.unique) var id: UUID
    var paymentDate: Date
    var amountPaid: Decimal
    var paymentMethod: String
    var referenceNote: String?
    /// Settlement currency when payment differs from invoice currency (wire / FX).
    var settlementCurrencyCode: String?
    var wireFee: Decimal?

    var invoice: Invoice?

    init(
        id: UUID = UUID(),
        paymentDate: Date = .now,
        amountPaid: Decimal,
        paymentMethod: String = "Wire",
        referenceNote: String? = nil,
        settlementCurrencyCode: String? = nil,
        wireFee: Decimal? = nil,
        invoice: Invoice? = nil
    ) {
        self.id = id
        self.paymentDate = paymentDate
        self.amountPaid = amountPaid
        self.paymentMethod = paymentMethod
        self.referenceNote = referenceNote
        self.settlementCurrencyCode = settlementCurrencyCode
        self.wireFee = wireFee
        self.invoice = invoice
    }
}
