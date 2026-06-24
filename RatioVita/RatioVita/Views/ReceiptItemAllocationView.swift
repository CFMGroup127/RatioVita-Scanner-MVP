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

    private var destinations: [SovereignEntityDestination] {
        CrossEntityReallocationService.destinations(ventures: ownedEntities, productions: productions)
    }

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
                "Assign each line to Personal, a venture, or a production. "
                    + "One master receipt can split across multiple hubs simultaneously. "
                    + "Unallocated pre-tax balance flows to Personal; HST splits proportionally."
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

            splitDestinationDiagram
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
    private var splitDestinationDiagram: some View {
        let buckets = destinationBuckets
        if buckets.count > 1 {
            GroupBox("Split destinations") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(buckets, id: \.label) { bucket in
                        HStack {
                            Text(bucket.label)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text(bucket.amount.formatted(.currency(code: receipt.currencyCode)))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    private struct DestinationBucket {
        var label: String
        var amount: Decimal
    }

    private var destinationBuckets: [DestinationBucket] {
        var buckets: [DestinationBucket] = []
        if summary.personalPreTax > 0 {
            buckets.append(DestinationBucket(label: "Personal Hub", amount: summary.personalPreTax))
        }
        for share in summary.entityShares {
            buckets.append(DestinationBucket(label: share.legalName, amount: share.preTaxAllocated))
        }
        for share in summary.productionShares {
            buckets.append(DestinationBucket(label: share.title, amount: share.preTaxAllocated))
        }
        return buckets
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
                if !isLocked {
                    lineDestinationMenu(for: line)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.ratioVitaAdaptiveSurface))
        .contextMenu {
            if !isLocked {
                let ids = selectedLineIDs.contains(line.id) && selectedLineIDs.count > 1
                    ? Array(selectedLineIDs)
                    : [line.id]
                contextAssignButtons(forLineIDs: ids)
            }
        }
    }

    @ViewBuilder
    private func lineDestinationMenu(for line: ReceiptLineItem) -> some View {
        Menu {
            contextAssignButtons(forLineIDs: [line.id])
        } label: {
            Label(
                CrossEntityReallocationService.destinationLabel(for: line),
                systemImage: "arrow.triangle.branch"
            )
            .font(.caption2)
        }
    }

    @ViewBuilder
    private func contextAssignButtons(forLineIDs ids: [UUID]) -> some View {
        ForEach(destinations) { destination in
            Button {
                CrossEntityReallocationService.apply(
                    destination: destination,
                    to: receipt,
                    lineIDs: ids,
                    modelContext: modelContext
                )
                selectedLineIDs.subtract(ids)
            } label: {
                Label(destination.title, systemImage: destination.systemImage)
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
                    ForEach(s.productionShares) { share in
                        LabeledContent("\(share.title) HST") {
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
            Text("Personal Hub")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.25)))
        } else if let project = line.allocatedProductionProject {
            Text(project.title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.2)))
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
