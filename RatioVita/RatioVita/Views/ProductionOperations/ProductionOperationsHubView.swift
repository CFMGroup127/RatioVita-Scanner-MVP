import SwiftData
import SwiftUI

/// Transport captain board, run tickets, PO queue, and venue tip ledger.
struct ProductionOperationsHubView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SovereignFeatureFlags.transportRunnerRoutingKey) private var transportEnabled = false
    @AppStorage(SovereignFeatureFlags.craftMicroTransactionsKey) private var craftMicroPay = false
    @AppStorage(SovereignFeatureFlags.venueGroupCheckoutKey) private var venueCheckout = false

    @Query(sort: \TransportDispatchTicket.createdAt, order: .reverse) private var dispatches: [TransportDispatchTicket]
    @Query(sort: \RunRequestTicket.createdAt, order: .reverse) private var runTickets: [RunRequestTicket]
    @Query(
        sort: \ProductionPurchaseOrder.createdAt,
        order: .reverse
    ) private var purchaseOrders: [ProductionPurchaseOrder]
    @Query(sort: \VenueCheckoutSession.createdAt, order: .reverse) private var venueSessions: [VenueCheckoutSession]
    @Query(sort: \CateringSupplyItem.updatedAt, order: .reverse) private var supplyItems: [CateringSupplyItem]

    @State private var selectedTab = 0
    @State private var simulateTipMessage: String?
    @State private var showPOCreation = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Module", selection: $selectedTab) {
                Text("Transport").tag(0)
                Text("Runs").tag(1)
                Text("POs").tag(2)
                if venueCheckout { Text("Venue").tag(3) }
                if craftMicroPay || supplyItems.count > 0 { Text("Supply").tag(4) }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selectedTab {
                    case 0: transportBoard
                    case 1: runsBoard
                    case 2: poBoard
                    case 3: venueBoard
                    default: supplyBoard
                }
            }
            .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, maxHeight: .infinity)
        }
        .navigationTitle("Production operations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPOCreation = true
                } label: {
                    Label("New PO", systemImage: "plus.circle")
                }
            }
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    ApprovalsInboxView()
                } label: {
                    Label("Approvals", systemImage: "checkmark.seal")
                }
            }
        }
        .sheet(isPresented: $showPOCreation) {
            PurchaseOrderCreationSheet()
        }
    }

    private var transportBoard: some View {
        List {
            if !transportEnabled {
                Text("Enable Transport runner routing in Module control cockpit.")
                    .foregroundStyle(.secondary)
            }
            ForEach(TransportRunnerService.sortedDispatchBoard(tickets: dispatches)) { ticket in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if ticket.isEmergencyShuttleRequest {
                            Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        Text(ticket.requiredVehicleScale.rawValue)
                            .font(.headline)
                        Spacer()
                        Text(ticket.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !ticket.requesterName.isEmpty {
                        Text(ticket.requesterName)
                            .font(.subheadline)
                    }
                    ForEach(ticket.routeLegs) { leg in
                        HStack {
                            Image(systemName: leg.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(leg.isCompleted ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(leg.locationName)
                                Text(leg.legDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var runsBoard: some View {
        List {
            Section {
                Button("Simulate 3D printer emergency run") {
                    simulateEmergencyRun()
                }
            }
            ForEach(runTickets) { ticket in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.requestingDepartment)
                        .font(.headline)
                    Text(ticket.urgency.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ticket.requestedItems, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        approvalChip("Dept", ticket.isApprovedByDeptHead)
                        if ticket.requiresPMApproval {
                            approvalChip("PM", ticket.isApprovedByPM)
                        }
                        if ticket.isGreenLit {
                            Label("Green light", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    if !ticket.contextualNote.isEmpty {
                        Text(ticket.contextualNote)
                            .font(.caption2)
                            .italic()
                    }
                }
            }
        }
    }

    private var poBoard: some View {
        List {
            ForEach(purchaseOrders) { po in
                VStack(alignment: .leading, spacing: 4) {
                    Text(po.vendorName)
                        .font(.headline)
                    Text(po.lineItemsSummary)
                        .font(.caption)
                    Text(verbatim: "$\(formatCAD(po.totalAmountCAD)) · \(po.approvalState.menuTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var venueBoard: some View {
        List {
            Section {
                Button("Simulate batch guest checkout") {
                    simulateCheckout()
                }
            }
            ForEach(venueSessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.hostName)
                        .font(.headline)
                    Text(verbatim:
                        "Food $\(formatCAD(session.foodSubtotalCAD)) · Tip $\(formatCAD(session.gratuityCAD)) · \(session.guestCardIdentifiers.count) cards"
                    )
                    .font(.caption)
                    Text(verbatim:
                        "Server $\(formatCAD(session.tipServerShareCAD)) · Bar $\(formatCAD(session.tipBartenderShareCAD)) · Support $\(formatCAD(session.tipSupportShareCAD))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            if let simulateTipMessage {
                Text(simulateTipMessage)
                    .font(.caption)
            }
        }
    }

    private var supplyBoard: some View {
        List {
            ForEach(supplyItems) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.listKind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.requiresPMApproval {
                        Text("PM pending")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func formatCAD(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func approvalChip(_ title: String, _ done: Bool) -> some View {
        Text("\(title): \(done ? "✓" : "…")")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(done ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    private func simulateEmergencyRun() {
        Task { @MainActor in
            do {
                let rules = try AccountingProtocolEngine.fetchOrCreateRules(
                    context: modelContext,
                    productionProjectID: nil
                )
                let ticket = RunRequestTicket(
                    requestingDepartment: "Props",
                    requestedByName: "Adam",
                    requestedItems: ["3D printer — high speed replacement"],
                    urgency: .setEmergencyRun,
                    contextualNote:
                    "Adam is at Best Buy checkout waiting for green light. Old unit failed on set.",
                    estimatedTotalCAD: 1299,
                    requiresPMApproval: true
                )
                _ = try TransportRunnerService.submitRunRequest(
                    context: modelContext,
                    ticket: ticket,
                    rules: rules
                )
                _ = try TransportRunnerService.deptHeadApprove(
                    context: modelContext,
                    ticket: ticket,
                    signerName: "Dept Head"
                )
            } catch {
                simulateTipMessage = error.localizedDescription
            }
        }
    }

    private func simulateCheckout() {
        do {
            let result = try FinTechTransactionEngine.processBatchGuestCards(
                context: modelContext,
                hostName: "Host",
                cardIdentifiers: ["CARD-1", "CARD-2", "CARD-3"],
                totalAmount: 420,
                gratuityAmount: 75
            )
            simulateTipMessage =
                "Cleared \(result.paymentReference) — server $\(formatCAD(result.tipShares.serverCAD))"
        } catch {
            simulateTipMessage = error.localizedDescription
        }
    }
}
