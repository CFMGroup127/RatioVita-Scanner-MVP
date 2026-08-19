import SwiftData
import SwiftUI

/// Editor for a single outgoing invoice: metadata, line items, payments, and running totals.
struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Bindable var invoice: Invoice

    @State private var showReceiptSelection = false
    @State private var showAddPayment = false
    @State private var showAddManualLineItem = false
    @State private var exportShareItem: ExportSharePayload?
    @State private var exportErrorMessage: String?

    private var sortedLineItems: [InvoiceLineItem] {
        invoice.lineItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var sortedPayments: [PaymentRecord] {
        invoice.paymentRecords.sorted { $0.paymentDate > $1.paymentDate }
    }

    var body: some View {
        Form {
            clientSection
            datesSection
            statusSection
            lineItemsSection
            paymentsSection
            totalsSection
            notesSection
        }
        .navigationTitle(invoice.invoiceNumber)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportInvoicePDF()
                } label: {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Share invoice PDF")
            }
        }
        .sheet(isPresented: $showReceiptSelection) {
            ReceiptSelectionSheet(invoice: invoice)
        }
        .sheet(isPresented: $showAddPayment) {
            AddPaymentRecordSheet(invoice: invoice)
        }
        .sheet(isPresented: $showAddManualLineItem) {
            AddManualLineItemSheet(invoice: invoice)
        }
        .sheet(item: $exportShareItem) { payload in
            ShareExportSheet(url: payload.url)
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Could not generate the invoice PDF.")
        }
    }

    private func exportInvoicePDF() {
        do {
            let url = try InvoicePDFGenerator.generatePDF(for: invoice)
            exportShareItem = ExportSharePayload(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private var clientSection: some View {
        Section("Client") {
            TextField("Client name", text: $invoice.clientName)
            TextField("Invoice number", text: $invoice.invoiceNumber)

            Picker("Currency", selection: $invoice.currencyCode) {
                ForEach(ReceiptCurrency.allCases) { currency in
                    Text(currency.displayLabel).tag(currency.code)
                }
            }
        }
    }

    private var datesSection: some View {
        Section("Dates") {
            DatePicker("Issue date", selection: $invoice.issueDate, displayedComponents: .date)
            DatePicker("Due date", selection: $invoice.dueDate, displayedComponents: .date)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Picker("Invoice status", selection: $invoice.status) {
                ForEach(InvoiceStatus.allCases) { status in
                    Text(status.displayTitle).tag(status)
                }
            }
            .pickerStyle(.segmented)

            InvoiceStatusBadge(status: invoice.status)
        }
    }

    private var lineItemsSection: some View {
        Section {
            ForEach(sortedLineItems, id: \.id) { item in
                InvoiceLineItemRowView(item: item, currencyCode: invoice.currencyCode)
            }
            .onDelete(perform: deleteLineItems)

            if sortedLineItems.isEmpty {
                Text("No line items yet. Attach verified receipts or add a manual charge.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Button {
                showReceiptSelection = true
            } label: {
                Label("Add from Receipts", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                showAddManualLineItem = true
            } label: {
                Label("Add Manual Line Item", systemImage: "plus.circle")
            }
        } header: {
            Text("Line Items")
        }
    }

    private var paymentsSection: some View {
        Section {
            ForEach(sortedPayments, id: \.id) { payment in
                PaymentRecordRowView(payment: payment, currencyCode: invoice.currencyCode)
            }
            .onDelete(perform: deletePayments)

            if sortedPayments.isEmpty {
                Text("No payments recorded.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Button {
                showAddPayment = true
            } label: {
                Label("Record Payment", systemImage: "banknote")
            }
        } header: {
            Text("Payments")
        }
    }

    private var totalsSection: some View {
        Section("Totals") {
            totalRow("Subtotal", amount: invoice.subtotal)
            totalRow("Tax", amount: invoice.totalTax)
            totalRow("Grand total", amount: invoice.grandTotal, emphasized: true)
            totalRow("Paid", amount: invoice.totalPaid)
            totalRow("Balance due", amount: invoice.balanceDue, emphasized: true, warning: invoice.balanceDue > .zero)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Internal notes", text: Binding(
                get: { invoice.notes ?? "" },
                set: { invoice.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private func totalRow(
        _ title: String,
        amount: Decimal,
        emphasized: Bool = false,
        warning: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? DesignSystem.Typography.bodyEmphasized : DesignSystem.Typography.body)
            Spacer()
            Text(CurrencyFormatter.shared.format(amount, currencyCode: invoice.currencyCode))
                .font(emphasized ? DesignSystem.Typography.bodyEmphasized : DesignSystem.Typography.body)
                .foregroundStyle(warning ? Color.ratioVitaWarning : Color.ratioVitaAdaptiveText)
        }
    }

    private func deleteLineItems(at offsets: IndexSet) {
        let items = sortedLineItems
        for index in offsets {
            InvoiceLineItemManager.removeLineItem(items[index], from: invoice, context: modelContext)
        }
    }

    private func deletePayments(at offsets: IndexSet) {
        let payments = sortedPayments
        for index in offsets {
            let payment = payments[index]
            invoice.paymentRecords.removeAll { $0.id == payment.id }
            modelContext.delete(payment)
        }
        invoice.updatedAt = .now
        try? modelContext.save()
    }
}

private struct InvoiceLineItemRowView: View {
    let item: InvoiceLineItem
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.itemDescription)
                .font(DesignSystem.Typography.bodyEmphasized)

            HStack(spacing: 4) {
                Text("Qty \(NSDecimalNumber(decimal: item.quantity).stringValue)")
                Text("·")
                Text(CurrencyFormatter.shared.format(item.unitPrice, currencyCode: currencyCode))
                if item.taxRate > .zero {
                    Text("·")
                    Text("Tax \(taxPercentLabel(for: item.taxRate))")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(Color.ratioVitaTextSecondary)

            if item.sourceReceipt != nil {
                Label("From receipt", systemImage: "link")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaInfo)
            }

            Text(CurrencyFormatter.shared.format(item.lineTotal + item.taxAmount, currencyCode: currencyCode))
                .font(DesignSystem.Typography.bodyEmphasized)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func taxPercentLabel(for rate: Decimal) -> String {
        let percent = (rate as NSDecimalNumber).doubleValue * 100
        return String(format: "%.0f%%", percent)
    }
}

private struct PaymentRecordRowView: View {
    let payment: PaymentRecord
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(CurrencyFormatter.shared.format(payment.amountPaid, currencyCode: currencyCode))
                    .font(DesignSystem.Typography.bodyEmphasized)
            }

            Text(payment.paymentMethod)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)

            if let note = payment.referenceNote, !note.isEmpty {
                Text(note)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
    }
}

private struct AddPaymentRecordSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let invoice: Invoice

    @State private var amountText = ""
    @State private var paymentDate = Date.now
    @State private var paymentMethod = "Wire"
    @State private var referenceNote = ""

    private let paymentMethods = ["Wire", "EFT", "Check", "Credit Card"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", text: $amountText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                Picker("Method", selection: $paymentMethod) {
                    ForEach(paymentMethods, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                TextField("Reference note", text: $referenceNote, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("Record Payment")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savePayment()
                            dismiss()
                        }
                        .disabled(parsedAmount == nil)
                    }
                }
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func savePayment() {
        guard let amount = parsedAmount else { return }
        let payment = PaymentRecord(
            paymentDate: paymentDate,
            amountPaid: amount,
            paymentMethod: paymentMethod,
            referenceNote: referenceNote.isEmpty ? nil : referenceNote,
            invoice: invoice
        )
        invoice.paymentRecords.append(payment)
        invoice.updatedAt = .now
        modelContext.insert(payment)
        try? modelContext.save()
    }
}

private struct AddManualLineItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let invoice: Invoice

    @State private var descriptionText = ""
    @State private var quantityText = "1"
    @State private var unitPriceText = ""
    @State private var taxRateText = "0"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Quantity", text: $quantityText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("Unit price", text: $unitPriceText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("Tax rate (0.13 = 13%)", text: $taxRateText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }
            .navigationTitle("Add Line Item")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            saveLineItem()
                            dismiss()
                        }
                        .disabled(!canSave)
                    }
                }
        }
    }

    private var canSave: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Decimal(string: quantityText) != nil
            && Decimal(string: unitPriceText) != nil
            && Decimal(string: taxRateText) != nil
    }

    private func saveLineItem() {
        guard let quantity = Decimal(string: quantityText),
              let unitPrice = Decimal(string: unitPriceText),
              let taxRate = Decimal(string: taxRateText) else { return }

        InvoiceLineItemManager.appendLineItem(
            to: invoice,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate,
            context: modelContext
        )
    }
}
