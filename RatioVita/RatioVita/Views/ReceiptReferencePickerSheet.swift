#if os(macOS)
import SwiftData
import SwiftUI

/// Searchable chooser to link the current receipt to another library record (invoice ↔ paycheck, etc.).
struct ReceiptReferencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var fromReceipt: Receipt
    /// When set, assigns `toReceipt` on this existing link instead of creating a new link.
    var linkToFill: ReceiptReferenceLink?

    @State private var searchText = ""

    private var sortedCandidates: [Receipt] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = candidates.filter { candidate in
            !isAlreadyLinked(to: candidate)
        }
        guard !term.isEmpty else { return base }
        return base.filter { r in
            if r.merchant.lowercased().contains(term) { return true }
            if r.notes?.lowercased().contains(term) == true { return true }
            if r.documentNumber?.lowercased().contains(term) == true { return true }
            if r.referenceInvoiceNumber?.lowercased().contains(term) == true { return true }
            if r.productionType?.lowercased().contains(term) == true { return true }
            if r.productionProject?.title.lowercased().contains(term) == true { return true }
            if r.department?.lowercased().contains(term) == true { return true }
            return false
        }
    }

    @Query private var candidates: [Receipt]

    init(fromReceipt: Receipt, linkToFill: ReceiptReferenceLink? = nil) {
        self.fromReceipt = fromReceipt
        self.linkToFill = linkToFill
        let excludeID = fromReceipt.id
        _candidates = Query(
            filter: #Predicate<Receipt> { r in
                r.id != excludeID && r.trashedAt == nil
            },
            sort: \Receipt.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            List(sortedCandidates, id: \.id) { target in
                Button {
                    applySelection(target)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(target.merchant)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack {
                            Text((target.transactionDate ?? target.createdAt).formatted(
                                date: .abbreviated,
                                time: .omitted
                            ))
                            Text(CurrencyFormatter.shared.format(target.total, currencyCode: target.currencyCode))
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if !target.documentType.isEmpty {
                            Text(target.documentType)
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(linkToFill == nil ? "Link related document" : "Choose linked document")
            .searchable(text: $searchText, prompt: "Search merchant, invoice #, notes…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    private func isAlreadyLinked(to target: Receipt) -> Bool {
        fromReceipt.referenceLinks.contains { $0.toReceipt?.id == target.id }
    }

    private func applySelection(_ target: Receipt) {
        if let link = linkToFill {
            link.toReceipt = target
        } else {
            guard !isAlreadyLinked(to: target) else {
                dismiss()
                return
            }
            let link = ReceiptReferenceLink(fromReceipt: fromReceipt, toReceipt: target, relationshipLabel: nil)
            modelContext.insert(link)
            fromReceipt.referenceLinks.append(link)
        }
        try? modelContext.save()
        dismiss()
    }
}
#endif
