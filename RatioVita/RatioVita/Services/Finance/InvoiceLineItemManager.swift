import Foundation
import SwiftData

/// Helpers for assembling and mutating outgoing invoice line items.
enum InvoiceLineItemManager {
    @MainActor
    @discardableResult
    static func appendLineItem(
        to invoice: Invoice,
        description: String,
        quantity: Decimal = 1,
        unitPrice: Decimal,
        taxRate: Decimal = .zero,
        sourceReceipt: Receipt? = nil,
        context: ModelContext
    ) -> InvoiceLineItem {
        let nextIndex = (invoice.lineItems.map(\.sortIndex).max() ?? -1) + 1
        let item = InvoiceLineItem(
            sortIndex: nextIndex,
            itemDescription: description,
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate,
            invoice: invoice,
            sourceReceipt: sourceReceipt
        )
        invoice.lineItems.append(item)
        invoice.updatedAt = .now
        try? context.save()
        return item
    }

    /// Builds a draft line item from an approved receipt total (receipt-to-invoice bundling).
    static func lineItem(from receipt: Receipt, taxRate: Decimal = .zero) -> InvoiceLineItem {
        let description = receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = receipt.documentNumber.map { " · \($0)" } ?? ""
        return InvoiceLineItem(
            itemDescription: description + detail,
            quantity: 1,
            unitPrice: abs(receipt.total),
            taxRate: taxRate,
            sourceReceipt: receipt
        )
    }

    @MainActor
    static func removeLineItem(_ item: InvoiceLineItem, from invoice: Invoice, context: ModelContext) {
        invoice.lineItems.removeAll { $0.id == item.id }
        invoice.updatedAt = .now
        context.delete(item)
        try? context.save()
    }
}
