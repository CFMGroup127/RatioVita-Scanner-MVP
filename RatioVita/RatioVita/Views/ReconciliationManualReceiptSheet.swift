//
//  ReconciliationManualReceiptSheet.swift
//  RatioVita
//
//  Searchable receipt picker when ranked bank ↔ receipt matching misses the right document.
//

import SwiftData
import SwiftUI

struct ReconciliationManualReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss

    let transaction: BankTransaction
    let receipts: [Receipt]
    let onPick: (Receipt) -> Void

    @State private var query = ""

    private var filtered: [Receipt] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = receipts.filter { $0.trashedAt == nil }
        guard !q.isEmpty else { return base.sorted { $0.createdAt > $1.createdAt } }
        return base.filter { r in
            r.merchant.lowercased().contains(q)
                || (r.notes ?? "").lowercased().contains(q)
                || (r.vendorAddress ?? "").lowercased().contains(q)
                || (r.documentNumber ?? "").lowercased().contains(q)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No receipts",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(
                            query.isEmpty
                                ? "No receipts in this currency, or all are in Trash."
                                : "Nothing matches that search."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered, id: \.id) { receipt in
                        Button {
                            onPick(receipt)
                            dismiss()
                        } label: {
                            manualReceiptRow(receipt)
                        }
                    }
                }
            }
            .navigationTitle("Manual match")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .searchable(text: $query, prompt: "Merchant, notes, address…")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private func manualReceiptRow(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                Spacer()
                if receipt.isLedgerLinked {
                    Text("Linked")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
            }
            Text(formatAmount(receipt.total, currency: receipt.currencyCode))
                .font(DesignSystem.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            if let d = receipt.transactionDate {
                Text(d.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.string(from: n) ?? "\(n) \(currency)"
    }
}
