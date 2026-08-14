import Foundation
import SwiftData

@Model
final class InvoiceLineItem {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var itemDescription: String
    var quantity: Decimal
    var unitPrice: Decimal
    /// Tax rate as a fraction (e.g. 0.13 for 13% HST).
    var taxRate: Decimal

    var invoice: Invoice?

    /// When bundled from an approved project receipt / expense.
    var sourceReceipt: Receipt?

    var lineTotal: Decimal {
        quantity * unitPrice
    }

    var taxAmount: Decimal {
        lineTotal * taxRate
    }

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        itemDescription: String,
        quantity: Decimal = 1,
        unitPrice: Decimal = .zero,
        taxRate: Decimal = .zero,
        invoice: Invoice? = nil,
        sourceReceipt: Receipt? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxRate = taxRate
        self.invoice = invoice
        self.sourceReceipt = sourceReceipt
    }
}
