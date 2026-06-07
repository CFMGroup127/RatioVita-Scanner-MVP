import SwiftData
import SwiftUI

/// Dual-unit tactical command — Algonquin surplus ↔ Muskoka evac (Sprint SSS).
struct CrisisSplitScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProductionUnitCrisisNode.updatedAt, order: .reverse) private var nodes: [ProductionUnitCrisisNode]

    @State private var selectedDrivers: Set<String> = []
    @State private var statusMessage: String?

    private var algonquin: ProductionUnitCrisisNode? {
        nodes.first { $0.unitNode == .mainUnitAlgonquin }
    }

    private var muskoka: ProductionUnitCrisisNode? {
        nodes.first { $0.unitNode == .secondUnitMuskoka }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            unitPane(algonquin, title: "Algonquin · Main", accent: .green)
            Divider()
            unitPane(muskoka, title: "Muskoka · Emergency", accent: .orange)
        }
        .navigationTitle("Crisis command matrix")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed units") { seed() }
            }
            ToolbarItem(placement: .automatic) {
                Button("Dispatch selected") { dispatch() }
                    .disabled(selectedDrivers.isEmpty)
            }
        }
        .onAppear {
            UserFrictionAnalytics.trackViewOpened("CrisisSplitScreen")
            seedIfNeeded()
        }
        .safeAreaInset(edge: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func unitPane(_ node: ProductionUnitCrisisNode?, title: String, accent: Color) -> some View {
        List {
            Section(title) {
                if let node {
                    Text(node.statusLabel)
                    LabeledContent("Crisis tier", value: node.crisisTier.label)
                    LabeledContent("Fleet trailers", value: "\(node.fleetTrailerCount)")
                    if !node.legacyLayoutTemplateID.isEmpty {
                        Text(MultiUnitCrisisDispatchEngine.applyLegacyLayoutMatch(node))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Tap Seed units to load demo nodes.")
                        .foregroundStyle(.secondary)
                }
            }
            if let node, node.unitNode == .mainUnitAlgonquin {
                Section("Surplus drivers") {
                    ForEach(node.surplusDriverTokens, id: \.self) { token in
                        Button {
                            toggle(token)
                        } label: {
                            HStack {
                                Text(token).font(.caption.monospaced())
                                Spacer()
                                if selectedDrivers.contains(token) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(accent)
                                }
                            }
                        }
                    }
                }
            }
            if let node, node.unitNode == .secondUnitMuskoka {
                Section("Inbound reroutes") {
                    if node.inboundDriverTokens.isEmpty {
                        Text("No inbound drivers yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(node.inboundDriverTokens, id: \.self) { token in
                        Text(token).font(.caption.monospaced())
                    }
                }
            }
        }
        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggle(_ token: String) {
        if selectedDrivers.contains(token) {
            selectedDrivers.remove(token)
        } else {
            selectedDrivers.insert(token)
        }
    }

    private func seedIfNeeded() {
        if nodes.isEmpty { seed() }
    }

    private func seed() {
        do {
            try MultiUnitCrisisDispatchEngine.seedDefaultNodes(context: modelContext)
            statusMessage = "Unit nodes seeded."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func dispatch() {
        do {
            try MultiUnitCrisisDispatchEngine.apportionDrivers(
                context: modelContext,
                from: .mainUnitAlgonquin,
                to: .secondUnitMuskoka,
                driverTokens: Array(selectedDrivers)
            )
            selectedDrivers.removeAll()
            statusMessage = "Delta apportionment posted to Comms."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
