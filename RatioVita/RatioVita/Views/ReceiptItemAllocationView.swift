import SwiftData
import SwiftUI

/// Line-by-line business / personal allocation with weighted HST waterfall.
struct ReceiptItemAllocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var receipt: Receipt
    var isLocked: Bool

    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ownedEntities: [BusinessEntity]

    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]

    @State private var selectedLineIDs: Set<UUID> = []

    private var sortedLines: [ReceiptLineItem] {
        receipt.lineItems.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var summary: ReceiptLineItemAllocationEngine.Summary {
        ReceiptLineItemAllocationEngine.summarize(
            lines: sortedLines,
            receiptSubtotal: receipt.subtotalAmount,
            receiptTax: receipt.taxAmount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(
                "Check line items, right-click, and assign to a corporation or Personal. "
                    + "Unallocated pre-tax balance flows to Personal; HST splits proportionally (CRA weighted method)."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if sortedLines.isEmpty {
                Text("No parsed line items — add rows under Line items or re-scan.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedLines, id: \.id) { line in
                    lineAllocationRow(line)
                }
            }

            waterfallSummaryCard

            if !isLocked {
                Button("Log allocation audit") {
                    logAllocationAudit()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func lineAllocationRow(_ line: ReceiptLineItem) -> some View {
        let preTax = ReceiptLineItemAllocationEngine.preTaxAmount(for: line)
        HStack(alignment: .top, spacing: 10) {
            Toggle(
                "",
                isOn: Binding(
                    get: { selectedLineIDs.contains(line.id) },
                    set: { on in
                        if on { selectedLineIDs.insert(line.id) }
                        else { selectedLineIDs.remove(line.id) }
                    }
                )
            )
            .labelsHidden()
            .disabled(isLocked)

            VStack(alignment: .leading, spacing: 4) {
                Text(line.lineDescription)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(preTax.formatted(.currency(code: receipt.currencyCode)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                allocationBadge(for: line)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.ratioVitaAdaptiveSurface))
        .contextMenu {
            if !isLocked {
                if selectedLineIDs.contains(line.id), selectedLineIDs.count > 1 {
                    contextAssignButtons(forLineIDs: Array(selectedLineIDs), label: "Assign selected to…")
                } else {
                    contextAssignButtons(forLineIDs: [line.id], label: "Assign to…")
                }
            }
        }
    }

    @ViewBuilder
    private func contextAssignButtons(forLineIDs ids: [UUID], label: String) -> some View {
        Button("\(label) Personal / Non-Business") {
            assignLines(ids, toPersonal: true, entity: nil, project: nil)
            selectedLineIDs.subtract(ids)
        }
        ForEach(ownedEntities) { entity in
            Button("\(label) \(entity.legalName)") {
                assignLines(ids, toPersonal: false, entity: entity, project: nil)
                selectedLineIDs.subtract(ids)
            }
        }
    }

    private var waterfallSummaryCard: some View {
        let s = summary
        return GroupBox("Balance waterfall") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Receipt subtotal") {
                    Text(s.receiptSubtotal.formatted(.currency(code: receipt.currencyCode)))
                }
                LabeledContent("Allocated (pre-tax)") {
                    Text(s.allocatedPreTax.formatted(.currency(code: receipt.currencyCode)))
                }
                LabeledContent("Unallocated → Personal") {
                    Text(s.unallocatedPreTax.formatted(.currency(code: receipt.currencyCode)))
                        .foregroundStyle(s.unallocatedPreTax > 0 ? Color.orange : Color.secondary)
                }
                if s.totalTax > 0 {
                    Divider()
                    ForEach(s.entityShares) { share in
                        LabeledContent("\(share.legalName) HST") {
                            Text(share.taxShare.formatted(.currency(code: receipt.currencyCode)))
                        }
                    }
                    LabeledContent("Personal HST share") {
                        Text(s.personalTaxShare.formatted(.currency(code: receipt.currencyCode)))
                    }
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func allocationBadge(for line: ReceiptLineItem) -> some View {
        if line.allocationIsPersonal {
            Text("Personal")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.25)))
        } else if let entity = line.allocatedBusinessEntity {
            Text(entity.legalName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.2)))
        } else {
            Text("Unallocated")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func assignLines(
        _ ids: [UUID],
        toPersonal: Bool,
        entity: BusinessEntity?,
        project: ProductionProject?
    ) {
        for line in sortedLines where ids.contains(line.id) {
            line.allocationIsPersonal = toPersonal
            line.allocatedBusinessEntity = toPersonal ? nil : entity
            line.allocatedProductionProject = toPersonal ? nil : project
        }
        try? modelContext.save()
    }

    private func logAllocationAudit() {
        FilingCoordinator.appendAudit(
            context: modelContext,
            kindRaw: FilingCoordinator.auditKindReceiptLineAllocation,
            title: "Mixed-use line allocation",
            detail: ReceiptLineItemAllocationEngine.auditDetail(summary: summary)
        )
        try? modelContext.save()
    }
}
