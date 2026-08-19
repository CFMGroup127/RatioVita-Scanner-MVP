import SwiftData
import SwiftUI

/// Master list of outgoing client invoices with status filtering and balance summaries.
struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Query(sort: \Invoice.issueDate, order: .reverse)
    private var invoices: [Invoice]

    @State private var statusFilter: InvoiceStatusFilter = .all
    @State private var navPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                statusPicker
                summaryBanner
                invoiceList
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createDraftInvoice()
                    } label: {
                        Label("New Invoice", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { invoiceID in
                InvoiceDetailByIDView(invoiceID: invoiceID)
            }
            .onAppear {
                InvoiceStatusManager.updateOverdueStatuses(in: modelContext)
            }
        }
    }

    private var statusPicker: some View {
        Picker("Status", selection: $statusFilter) {
            ForEach(InvoiceStatusFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var summaryBanner: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            SectionHeader(
                title: statusFilter.title,
                subtitle: "\(filteredInvoices.count) invoice\(filteredInvoices.count == 1 ? "" : "s")"
            )
            .padding(.horizontal, DesignSystem.Spacing.md)

            if filteredInvoices.isEmpty {
                Text("No invoices in this segment.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            } else if summarySingleCurrencyCode != nil {
                Text("Balance due: \(CurrencyFormatter.shared.format(summaryBalanceDue, currencyCode: summarySingleCurrencyCode!))")
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .foregroundStyle(brandAccent)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            } else {
                Text("Balance due spans \(summaryCurrencyCount) currencies")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var summaryBalanceDue: Decimal {
        filteredInvoices.reduce(.zero) { $0 + $1.balanceDue }
    }

    private var summaryCurrencyCount: Int {
        Set(filteredInvoices.map(\.currencyCode)).count
    }

    private var summarySingleCurrencyCode: String? {
        let codes = Set(filteredInvoices.map(\.currencyCode))
        guard codes.count == 1 else { return nil }
        return codes.first
    }

    @ViewBuilder
    private var invoiceList: some View {
        if filteredInvoices.isEmpty {
            ContentUnavailableView(
                "No invoices yet",
                systemImage: "doc.text",
                description: Text("Create a draft invoice, then attach verified receipts as billable line items.")
            )
        } else {
            List {
                ForEach(filteredInvoices, id: \.id) { invoice in
                    Button {
                        navPath.append(invoice.id)
                    } label: {
                        InvoiceRowView(invoice: invoice)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }

    private var filteredInvoices: [Invoice] {
        guard let status = statusFilter.invoiceStatus else { return invoices }
        return invoices.filter { $0.status == status }
    }

    private func createDraftInvoice() {
        let sequence = invoices.count + 1
        let number = "INV-\(Self.invoiceNumberStamp())-\(sequence)"
        let invoice = Invoice(
            invoiceNumber: number,
            clientName: "New Client",
            currencyCode: AppCurrencySettings.defaultCurrencyCode
        )
        modelContext.insert(invoice)
        try? modelContext.save()
        navPath.append(invoice.id)
    }

    private static func invoiceNumberStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: .now)
    }
}

private enum InvoiceStatusFilter: String, CaseIterable, Identifiable {
    case all
    case draft
    case sent
    case paid
    case overdue

    var id: String { rawValue }

    var title: String {
        switch self {
            case .all: "All"
            case .draft: InvoiceStatus.draft.displayTitle
            case .sent: InvoiceStatus.sent.displayTitle
            case .paid: InvoiceStatus.paid.displayTitle
            case .overdue: InvoiceStatus.overdue.displayTitle
        }
    }

    var invoiceStatus: InvoiceStatus? {
        switch self {
            case .all: nil
            case .draft: .draft
            case .sent: .sent
            case .paid: .paid
            case .overdue: .overdue
        }
    }
}

private struct InvoiceRowView: View {
    let invoice: Invoice

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.clientName)
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)

                Text(invoice.invoiceNumber)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)

                Text("Due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                InvoiceStatusBadge(status: invoice.status)

                Text(CurrencyFormatter.shared.format(invoice.grandTotal, currencyCode: invoice.currencyCode))
                    .font(DesignSystem.Typography.bodyEmphasized)

                if invoice.balanceDue > .zero, invoice.status != .paid {
                    Text(
                        "Due \(CurrencyFormatter.shared.format(invoice.balanceDue, currencyCode: invoice.currencyCode))"
                    )
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaWarning)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct InvoiceStatusBadge: View {
    let status: InvoiceStatus

    var body: some View {
        StatusBadge(
            text: status.displayTitle,
            backgroundColor: backgroundColor
        )
    }

    private var backgroundColor: Color {
        switch status {
            case .draft: Color.ratioVitaTextSecondary.opacity(0.35)
            case .sent: Color.ratioVitaInfo
            case .paid: Color.ratioVitaSuccess
            case .overdue: Color.ratioVitaError
        }
    }
}
