import SwiftData
import SwiftUI

/// Unified dept head / PM / accounting sign-off surface.
struct ApprovalsInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""

    @Query(sort: \RunRequestTicket.createdAt, order: .reverse) private var runTickets: [RunRequestTicket]
    @Query(
        sort: \ProductionPurchaseOrder.createdAt,
        order: .reverse
    ) private var purchaseOrders: [ProductionPurchaseOrder]
    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var timecardDays: [CrewTimecardDay]
    @Query(sort: \ConsultationTimecard.createdAt, order: .reverse) private var consultTimecards: [ConsultationTimecard]

    @State private var segment = "runs"

    private var showConsultantVault: Bool {
        ConsultantSessionManager.shared.programModeEnabled
            || HierarchyCommsEngine.userOperationalRole.lowercased().contains("account")
    }

    private var showPurchaseOrderQueue: Bool {
        let role = HierarchyCommsEngine.userOperationalRole.lowercased()
        return role.contains("pm")
            || role.contains("producer")
            || role.contains("account")
            || role.contains("dept")
            || role.contains("head")
            || role.contains("coordinator")
            || role.contains("cfo")
            || role.contains("clo")
    }

    @State private var signerName = ""
    @State private var rules: ProductionApprovalRule?
    @State private var selectedTimecardID: UUID?
    @State private var timecardSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Queue", selection: $segment) {
                Text("Runs (\(pendingRuns.count))").tag("runs")
                if showPurchaseOrderQueue {
                    Text("POs (\(pendingPOs.count))").tag("pos")
                }
                Text("Timecards (\(pendingTimecards.count))").tag("timecards")
                if showConsultantVault {
                    Text("Consult (\(consultTimecards.count))").tag("consult")
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if segment == "timecards" {
                timecardSplitInbox
            } else if segment == "consult" {
                consultantVaultBody
            } else {
                legacyQueueBody
            }
        }
        .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, maxHeight: .infinity)
        .navigationTitle("Approvals inbox")
        .task { await loadRules() }
        .onAppear {
            if selectedTimecardID == nil {
                selectedTimecardID = filteredPendingTimecards.first?.id
            }
        }
        .onChange(of: pendingTimecards.count) { _, _ in
            if let id = selectedTimecardID,
               !pendingTimecards.contains(where: { $0.id == id })
            {
                selectedTimecardID = filteredPendingTimecards.first?.id
            }
        }
    }

    // MARK: - Timecard split-screen

    private var timecardSplitInbox: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 8) {
                TextField("Search dept, unit, date…", text: $timecardSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                List(selection: $selectedTimecardID) {
                    if filteredPendingTimecards.isEmpty {
                        Text("No pending timecards.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filteredPendingTimecards) { day in
                        timecardListRow(day)
                            .tag(day.id)
                    }
                }
            }
            .frame(width: SafeLayoutBounds.inboxListWidth)

            Divider()

            Group {
                if let day = selectedTimecard, let rules {
                    TimecardApprovalDetailView(
                        day: day,
                        siblingDays: siblingDays(for: day),
                        rules: rules
                    )
                } else {
                    ContentUnavailableView(
                        "Select a timecard",
                        systemImage: "calendar.day.timeline.left",
                        description: Text(
                            "Each row is one approval set (one day / dept / unit). \(pendingTimecards.count) pending."
                        )
                    )
                }
            }
            .frame(
                minWidth: 400,
                maxWidth: SafeLayoutBounds.maxDetailPaneWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, maxHeight: .infinity)
    }

    private var filteredPendingTimecards: [CrewTimecardDay] {
        let q = timecardSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return pendingTimecards }
        return pendingTimecards.filter { day in
            day.workDate.formatted(date: .abbreviated, time: .omitted).lowercased().contains(q)
                || (day.department ?? "").lowercased().contains(q)
                || (day.unitType ?? "").lowercased().contains(q)
                || (day.occupationTitle ?? "").lowercased().contains(q)
        }
    }

    private var selectedTimecard: CrewTimecardDay? {
        guard let id = selectedTimecardID else { return nil }
        return pendingTimecards.first { $0.id == id }
    }

    private func siblingDays(for day: CrewTimecardDay) -> [CrewTimecardDay] {
        guard let pid = day.productionProject?.id else { return timecardDays }
        return timecardDays.filter { $0.productionProject?.id == pid }
    }

    private func timecardListRow(_ day: CrewTimecardDay) -> some View {
        let states = TimecardApprovalService.boxStates(for: day)
        return VStack(alignment: .leading, spacing: 6) {
            Text(day.workDate.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            Text("\(day.department ?? "Dept") · \(day.unitType ?? "Unit")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                miniBox("Crew", states[.crew]?.isComplete == true)
                miniBox("Key", states[.departmentHead]?.isComplete == true)
                miniBox("PM", states[.productionManager]?.isComplete == true)
                miniBox("Acct", states[.accounting]?.isComplete == true)
            }
        }
        .padding(.vertical, 4)
    }

    private func miniBox(_ title: String, _ done: Bool) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .frame(width: 36, height: 18)
            .background(done ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Consultant accounting vault

    private var consultantVaultBody: some View {
        List {
            if consultTimecards.isEmpty {
                Text("No consultant honorarium cards — experts submit via Expert program.")
                    .foregroundStyle(.secondary)
            }
            ForEach(consultTimecards) { card in
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.anonymousToken)
                        .font(.headline.monospaced())
                    Text("\(card.hoursLogged, format: .number) h · \(card.departmentScopeRaw)")
                    Text(card.localizedNotes)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Runs / PO legacy list

    private var legacyQueueBody: some View {
        Group {
            TextField("Signer name (runs / POs)", text: $signerName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            List {
                switch segment {
                    case "runs": runsSection
                    case "pos": poSection
                    default: EmptyView()
                }
            }
        }
    }

    private var pendingRuns: [RunRequestTicket] {
        runTickets.filter { !$0.isGreenLit }
    }

    private var pendingPOs: [ProductionPurchaseOrder] {
        purchaseOrders.filter { $0.approvalState != .accountingCleared && $0.approvalState != .rejected }
    }

    private var pendingTimecards: [CrewTimecardDay] {
        timecardDays.filter { $0.approvalState != .accountingCleared }
    }

    @ViewBuilder
    private var runsSection: some View {
        if pendingRuns.isEmpty {
            Text("No pending run tickets.")
                .foregroundStyle(.secondary)
        }
        ForEach(pendingRuns) { ticket in
            VStack(alignment: .leading, spacing: 8) {
                Text(ticket.requestingDepartment)
                    .font(.headline)
                approvalTrail(
                    dept: ticket.isApprovedByDeptHead,
                    pm: !ticket.requiresPMApproval || ticket.isApprovedByPM,
                    accounting: ticket.isGreenLit
                )
                HStack {
                    if !ticket.isApprovedByDeptHead {
                        approveButton("Dept head sign") {
                            _ = try? TransportRunnerService.deptHeadApprove(
                                context: modelContext,
                                ticket: ticket,
                                signerName: signerName.isEmpty ? "Dept Head" : signerName
                            )
                        }
                    } else if ticket.requiresPMApproval, !ticket.isApprovedByPM {
                        approveButton("PM authorize") {
                            _ = try? TransportRunnerService.pmApprove(context: modelContext, ticket: ticket)
                        }
                    } else if !ticket.isGreenLit {
                        approveButton("Green light driver") {
                            _ = try? TransportRunnerService.assignDriverAndGreenLight(
                                context: modelContext,
                                ticket: ticket,
                                driverIdentifier: "Driver-1"
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var poSection: some View {
        if pendingPOs.isEmpty {
            Text("No pending purchase orders.")
                .foregroundStyle(.secondary)
        }
        ForEach(pendingPOs) { po in
            VStack(alignment: .leading, spacing: 8) {
                Text(po.vendorName)
                    .font(.headline)
                Text(verbatim: "$\(formatCAD(po.totalAmountCAD)) · \(po.approvalState.menuTitle)")
                    .font(.caption)
                if let rules {
                    let steps = AccountingProtocolEngine.requiredStepsForPurchaseOrder(
                        amount: po.totalAmountCAD,
                        submittedByRole: po.submittedByRole,
                        rules: rules
                    )
                    Text(requiredStepsLabel(steps))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    approveButton("Dept") {
                        guard let rules else { return }
                        AccountingProtocolEngine.advancePurchaseOrder(
                            po: po,
                            rules: rules,
                            signerName: signerName.isEmpty ? "Dept Head" : signerName,
                            role: .departmentHead
                        )
                        try? modelContext.save()
                    }
                    approveButton("PM") {
                        guard let rules else { return }
                        AccountingProtocolEngine.advancePurchaseOrder(
                            po: po,
                            rules: rules,
                            signerName: signerName.isEmpty ? "PM" : signerName,
                            role: .productionManager
                        )
                        try? modelContext.save()
                    }
                    approveButton("Accounting") {
                        guard let rules else { return }
                        AccountingProtocolEngine.advancePurchaseOrder(
                            po: po,
                            rules: rules,
                            signerName: signerName.isEmpty ? "Accounting" : signerName,
                            role: .accounting
                        )
                        try? modelContext.save()
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func approvalTrail(dept: Bool, pm: Bool, accounting: Bool) -> some View {
        HStack(spacing: 6) {
            stepChip("Dept", dept)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 12)
            stepChip("PM", pm)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 12)
            stepChip("Acct", accounting)
        }
    }

    private func stepChip(_ title: String, _ done: Bool) -> some View {
        Text("\(title) \(done ? "✓" : "…")")
            .font(.caption2)
            .frame(width: FixedColumnWidths.approvalBoxWidth, alignment: .center)
            .padding(.vertical, 2)
            .background(done ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }

    private func approveButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    private func requiredStepsLabel(_ steps: AccountingProtocolEngine.RequiredApprovalSteps) -> String {
        var parts: [String] = []
        if steps.needsDeptHead { parts.append("Dept head") }
        if steps.needsPM { parts.append("PM") }
        if steps.needsAccounting { parts.append("Accounting") }
        if steps.needsExecutive { parts.append("Executive") }
        return "Requires: " + (parts.isEmpty ? "None" : parts.joined(separator: " → "))
    }

    private func formatCAD(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func loadRules() async {
        let pid = UUID(uuidString: forensicActiveProductionID)
        rules = try? AccountingProtocolEngine.fetchOrCreateRules(
            context: modelContext,
            productionProjectID: pid
        )
        if let rules,
           let override = UserDefaults.standard.object(forKey: RuntimeConfigKeys.pettyCashOverrideKey) as? Double
        {
            rules.pettyCashAutoApproveCAD = Decimal(override)
        }
    }
}
