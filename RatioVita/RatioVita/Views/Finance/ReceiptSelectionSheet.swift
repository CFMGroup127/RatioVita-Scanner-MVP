import SwiftData
import SwiftUI

/// Modal picker that bundles verified vault receipts into invoice line items.
struct ReceiptSelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAccent) private var brandAccent

    let invoice: Invoice

    @Query(
        filter: #Predicate<Receipt> {
            !$0.pendingHumanReview && $0.trashedAt == nil && $0.isVerified
        },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var receipts: [Receipt]

    @State private var selectedReceiptIDs: Set<UUID> = []
    /// `nil` = All productions.
    @State private var selectedProjectFilterID: UUID?

    private var attachedReceiptIDs: Set<UUID> {
        Set(invoice.lineItems.compactMap(\.sourceReceipt?.id))
    }

    private var selectableReceipts: [Receipt] {
        receipts.filter { !attachedReceiptIDs.contains($0.id) }
    }

    private var availableProjects: [ProductionProject] {
        var seen = Set<UUID>()
        return receipts.compactMap(\.productionProject)
            .filter { seen.insert($0.id).inserted }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private var filteredReceipts: [Receipt] {
        guard let selectedProjectFilterID else { return selectableReceipts }
        return selectableReceipts.filter { $0.productionProject?.id == selectedProjectFilterID }
    }

    private var showsProjectFilterBar: Bool {
        availableProjects.count > 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsProjectFilterBar {
                    projectFilterBar
                    Divider()
                }

                receiptListContent
            }
            .navigationTitle("Attach Receipts")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import Selected (\(selectedReceiptIDs.count))") {
                        importSelectedReceipts()
                        dismiss()
                    }
                    .disabled(selectedReceiptIDs.isEmpty)
                }
            }
            .onAppear {
                applyDefaultProjectFilterIfNeeded()
            }
            .onChange(of: selectedProjectFilterID) { _, _ in
                pruneSelectionToVisibleReceipts()
            }
        }
    }

    private var projectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                projectFilterChip(title: "All", projectID: nil)

                ForEach(availableProjects, id: \.id) { project in
                    projectFilterChip(title: project.title, projectID: project.id)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(Color.ratioVitaAdaptiveSurface)
    }

    @ViewBuilder
    private func projectFilterChip(title: String, projectID: UUID?) -> some View {
        let isSelected = selectedProjectFilterID == projectID
        Button {
            selectedProjectFilterID = projectID
        } label: {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(isSelected ? brandAccent : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var receiptListContent: some View {
        if selectableReceipts.isEmpty {
            ContentUnavailableView(
                "No receipts available",
                systemImage: "doc.text.magnifyingglass",
                description: Text(
                    attachedReceiptIDs.isEmpty
                        ? "Verify receipts in Review before attaching them to an invoice."
                        : "Every verified receipt is already attached to this invoice."
                )
            )
        } else if filteredReceipts.isEmpty {
            ContentUnavailableView(
                "No receipts for this production",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Try selecting All or a different production filter.")
            )
        } else {
            List {
                ForEach(filteredReceipts, id: \.id) { receipt in
                    receiptRow(receipt)
                }
            }
        }
    }

    @ViewBuilder
    private func receiptRow(_ receipt: Receipt) -> some View {
        let isSelected = selectedReceiptIDs.contains(receipt.id)
        let displayDate = receipt.transactionDate ?? receipt.createdAt

        Button {
            toggleSelection(for: receipt)
        } label: {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Unknown Merchant"
                        : receipt.merchant)
                        .font(DesignSystem.Typography.bodyEmphasized)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(displayDate, style: .date)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)

                        if let projectTitle = receipt.productionProject?.title,
                           !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("·")
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            Text(projectTitle)
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(brandAccent)
                                .lineLimit(1)
                        }
                    }

                    if receipt.currencyCode != invoice.currencyCode {
                        Text("Currency: \(receipt.currencyCode)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(Color.ratioVitaWarning)
                    }
                }

                Spacer()

                Text(CurrencyFormatter.shared.format(abs(receipt.total), currencyCode: receipt.currencyCode))
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applyDefaultProjectFilterIfNeeded() {
        guard selectedProjectFilterID == nil,
              let invoiceProject = invoice.productionProject else { return }
        let matchesAvailable = availableProjects.contains { $0.id == invoiceProject.id }
        if matchesAvailable {
            selectedProjectFilterID = invoiceProject.id
        }
    }

    private func pruneSelectionToVisibleReceipts() {
        let visibleIDs = Set(filteredReceipts.map(\.id))
        selectedReceiptIDs = selectedReceiptIDs.intersection(visibleIDs)
    }

    private func toggleSelection(for receipt: Receipt) {
        if selectedReceiptIDs.contains(receipt.id) {
            selectedReceiptIDs.remove(receipt.id)
        } else {
            selectedReceiptIDs.insert(receipt.id)
        }
    }

    private func importSelectedReceipts() {
        let chosen = filteredReceipts.filter { selectedReceiptIDs.contains($0.id) }
        InvoiceLineItemManager.appendLineItems(from: chosen, to: invoice, context: modelContext)
    }
}
