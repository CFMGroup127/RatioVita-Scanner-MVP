import SwiftData
import SwiftUI

/// Cross-entity inbox triage — mixed Amazon / personal inbox imports awaiting hub routing.
struct InboxTriageFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @ObservedObject private var context = SovereignContextManager.shared

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var allActiveReceipts: [Receipt]

    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ventureEntities: [BusinessEntity]

    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]

    @State private var selectedReceipt: Receipt?
    @State private var selectedLineIDs: Set<UUID> = []

    private var triageReceipts: [Receipt] {
        allActiveReceipts.filter(CrossEntityTriageEngine.needsTriage)
    }

    private var destinations: [SovereignEntityDestination] {
        CrossEntityReallocationService.destinations(
            ventures: ventureEntities,
            productions: productions
        )
    }

    private var scopedReceipts: [Receipt] {
        triageReceipts.filter { SovereignScopeFilter.triageReceiptIsVisible($0, context: context) }
    }

    var body: some View {
        List {
            Section {
                Text(
                    "Mixed-use imports land here first. Slice line items and route gifts to Personal, "
                        + "set supplies to a production, and architectural assets to a venture."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            if scopedReceipts.isEmpty {
                ContentUnavailableView(
                    "Inbox clear",
                    systemImage: "tray",
                    description: Text("No cross-entity items waiting for triage.")
                )
            } else {
                ForEach(scopedReceipts, id: \.id) { receipt in
                    triageRow(receipt)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedReceipt = receipt
                            selectedLineIDs = []
                        }
                }
            }
        }
        .navigationTitle("Inbox Triage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .top, spacing: 0) {
            SovereignContextSwitcherBar()
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .onAppear {
            CrossEntityTriageEngine.scanLinkedInboxImports(modelContext: modelContext)
        }
        .sheet(isPresented: Binding(
            get: { selectedReceipt != nil },
            set: { if !$0 { selectedReceipt = nil } }
        )) {
            if let receipt = selectedReceipt {
                NavigationStack {
                    InboxTriageDetailView(
                        receipt: receipt,
                        destinations: destinations,
                        selectedLineIDs: $selectedLineIDs
                    )
                }
                #if os(iOS)
                .presentationDetents([.large])
                #endif
            }
        }
    }

    @ViewBuilder
    private func triageRow(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Spacer()
                Text(receipt.total.formatted(.currency(code: receipt.currencyCode)))
                    .font(DesignSystem.Typography.caption.monospacedDigit())
            }

            if let inbox = receipt.sourceSecureInboxEmail, !inbox.isEmpty {
                Label(inbox, systemImage: "envelope.badge.shield.half.filled")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            HStack(spacing: 8) {
                Label("\(receipt.lineItems.count) lines", systemImage: "list.bullet")
                if receipt.lineItems.contains(where: { !$0.allocationIsPersonal && $0.allocatedBusinessEntity == nil && $0.allocatedProductionProject == nil }) {
                    StatusBadge.warning("Needs routing")
                } else {
                    StatusBadge.info("Partially routed")
                }
            }
            .font(DesignSystem.Typography.caption2)
        }
        .padding(.vertical, 4)
    }
}

private struct InboxTriageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var receipt: Receipt
    let destinations: [SovereignEntityDestination]
    @Binding var selectedLineIDs: Set<UUID>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(receipt.merchant)
                        .font(DesignSystem.Typography.title3.weight(.semibold))
                    Text(receipt.total.formatted(.currency(code: receipt.currencyCode)))
                        .font(DesignSystem.Typography.body)
                    if let inbox = receipt.sourceSecureInboxEmail {
                        Text("Discovered via \(inbox)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    }
                }

                reallocateWholeReceiptSection

                Divider()

                ReceiptItemAllocationView(receipt: receipt, isLocked: false)

                if CrossEntityTriageEngine.isFullyTriaged(receipt) {
                    Button("Mark triage complete") {
                        receipt.crossEntityTriagedAt = .now
                        receipt.requiresCrossEntityTriage = false
                        try? modelContext.save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .navigationTitle("Re-allocate")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var reallocateWholeReceiptSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Route entire receipt")
                .font(DesignSystem.Typography.bodyEmphasized)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(destinations) { destination in
                        Button {
                            CrossEntityReallocationService.apply(
                                destination: destination,
                                to: receipt,
                                lineIDs: nil,
                                modelContext: modelContext
                            )
                        } label: {
                            Label(destination.title, systemImage: destination.systemImage)
                                .font(DesignSystem.Typography.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.ratioVitaAdaptiveSurface))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
