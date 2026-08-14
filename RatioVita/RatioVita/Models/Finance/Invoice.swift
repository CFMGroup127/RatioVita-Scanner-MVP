import Foundation
import SwiftData

/// Outgoing client invoice (B2B billing) with multi-currency support and payment tracking.
@Model
final class Invoice {
    @Attribute(.unique) var id: UUID
    var invoiceNumber: String
    var clientName: String
    var issueDate: Date
    var dueDate: Date
    var rawStatus: String
    var currencyCode: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \InvoiceLineItem.invoice)
    var lineItems: [InvoiceLineItem]

    @Relationship(deleteRule: .cascade, inverse: \PaymentRecord.invoice)
    var paymentRecords: [PaymentRecord]

    /// Optional production / show context for crew billing.
    var productionProject: ProductionProject?

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: rawStatus) ?? .draft }
        set {
            rawStatus = newValue.rawValue
            updatedAt = .now
        }
    }

    var subtotal: Decimal {
        lineItems.reduce(.zero) { $0 + $1.lineTotal }
    }

    var totalTax: Decimal {
        lineItems.reduce(.zero) { $0 + $1.taxAmount }
    }

    var grandTotal: Decimal {
        subtotal + totalTax
    }

    var totalPaid: Decimal {
        paymentRecords.reduce(.zero) { $0 + $1.amountPaid }
    }

    var balanceDue: Decimal {
        max(.zero, grandTotal - totalPaid)
    }

    init(
        id: UUID = UUID(),
        invoiceNumber: String,
        clientName: String,
        issueDate: Date = .now,
        dueDate: Date? = nil,
        status: InvoiceStatus = .draft,
        currencyCode: String = AppCurrencySettings.defaultCurrencyCode,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        productionProject: ProductionProject? = nil,
        lineItems: [InvoiceLineItem] = [],
        paymentRecords: [PaymentRecord] = []
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.clientName = clientName
        self.issueDate = issueDate
        self.dueDate = dueDate
            ?? Calendar.current.date(byAdding: .day, value: 30, to: issueDate)
            ?? issueDate
        rawStatus = status.rawValue
        self.currencyCode = currencyCode
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productionProject = productionProject
        self.lineItems = lineItems
        self.paymentRecords = paymentRecords
    }
}
