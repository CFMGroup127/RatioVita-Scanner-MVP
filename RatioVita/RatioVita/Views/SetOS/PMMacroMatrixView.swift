import SwiftData
import SwiftUI

/// PM / Showrunner zero-chatter executive cockpit (Sprint VVV).
struct PMMacroMatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var session = ConsultantSessionManager.shared
    @Query(
        sort: \ExecutiveLogisticsSnapshot.updatedAt,
        order: .reverse
    ) private var snapshots: [ExecutiveLogisticsSnapshot]
    @Query(sort: \LocationsGreenZone.zoneName) private var greenZones: [LocationsGreenZone]
    @Query(
        sort: \ProductionUnitCrisisNode.updatedAt,
        order: .reverse
    ) private var crisisNodes: [ProductionUnitCrisisNode]

    @State private var selectedDepartment: DepartmentMacroTile?
    @State private var statusMessage: String?

    private var snapshot: ExecutiveLogisticsSnapshot? { snapshots.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                header
                macroGrid
                if let selectedDepartment {
                    detailDrawer(selectedDepartment)
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Executive matrix")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh macro state") { refresh() }
            }
            ToolbarItem(placement: .automatic) {
                Button("Seed demo data") { seed() }
            }
        }
        .onAppear {
            UserFrictionAnalytics.trackViewOpened("PMMacroMatrix")
            refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PM · Showrunner command matrix")
                .font(.title2.bold())
            Text("Zero chatter — macro structural health only. Tap a tile for an isolated drawer.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let snapshot {
                Label(snapshot.crisisTier.label, systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot.crisisTier == .activeEvacuation ? .orange : .secondary)
            }
        }
    }

    private var macroGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)],
            spacing: 14
        ) {
            locationsTile
            hmwTile
            transportTile
            accommodationsTile
        }
    }

    private var locationsTile: some View {
        macroTile(
            .locations,
            title: "Locations green zones",
            value: zoneSummary,
            footnote: "Tristan / LAM safe zones + overhead notes",
            tint: .teal
        )
    }

    private var hmwTile: some View {
        macroTile(
            .hmw,
            title: "HMW structural status",
            value: hmwSummary,
            footnote: "Trailers · shuttles · shore power",
            tint: .purple
        )
    }

    private var transportTile: some View {
        macroTile(
            .transport,
            title: "Transport evac telemetry",
            value: transportSummary,
            footnote: "Muskoka fleet node + inbound drivers",
            tint: .orange
        )
    }

    private var accommodationsTile: some View {
        macroTile(
            .accommodations,
            title: "Hotel crosswalk",
            value: bedSummary,
            footnote: "Call sheet headcount vs secured rooms",
            tint: .blue
        )
    }

    private var zoneSummary: String {
        guard let snapshot else { return "—" }
        return "\(snapshot.locationsGreenZonesSecured) / \(snapshot.locationsGreenZonesTotal) zones active"
    }

    private var hmwSummary: String {
        guard let snapshot else { return "—" }
        if snapshot.hmwTrailersLocked, snapshot.castShuttlesAligned {
            return "SECURED · SHUTTLES ALIGNED"
        }
        return snapshot.hmwTrailersLocked ? "Trailers locked" : "Staging"
    }

    private var transportSummary: String {
        let muskoka = crisisNodes.first { $0.unitNode == .secondUnitMuskoka }
        let ready = snapshot?.transportFleetReadyCount ?? muskoka?.inboundDriverTokens.count ?? 0
        let total = snapshot?.transportFleetTotal ?? muskoka?.fleetTrailerCount ?? 30
        return "\(total) trailers prepped · \(ready) inbound drivers"
    }

    private var bedSummary: String {
        guard let snapshot else { return "—" }
        return "\(snapshot.securedHotelRoomsCount) rooms / \(snapshot.activeCallSheetHeadcount) crew+cast"
    }

    private func macroTile(
        _ tile: DepartmentMacroTile,
        title: String,
        value: String,
        footnote: String,
        tint: Color
    ) -> some View {
        Button {
            selectedDepartment = selectedDepartment == tile ? nil : tile
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: tile.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .multilineTextAlignment(.leading)
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                    .stroke(selectedDepartment == tile ? tint : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailDrawer(_ tile: DepartmentMacroTile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tile.drawerTitle)
                .font(.headline)
            switch tile {
                case .locations:
                    ForEach(greenZones) { zone in
                        Text("• \(zone.zoneName) — \(zone.securedHotelRooms) rooms")
                            .font(.caption)
                    }
                    NavigationLink("Open Locations PA hub") { LocationsPAHubView() }
                case .hmw:
                    Text("Hair/Makeup/Wardrobe trailers: \(hmwSummary)")
                    Text("Cast shuttles: \(snapshot?.castShuttlesAligned == true ? "ALIGNED & MANNED" : "Staging")")
                    Text("Genny op: \(snapshot?.gennyStandby == true ? "STANDBY" : "Nominal")")
                        .font(.caption)
                case .transport:
                    if let muskoka = crisisNodes.first(where: { $0.unitNode == .secondUnitMuskoka }) {
                        Text(muskoka.statusLabel)
                        Text(MultiUnitCrisisDispatchEngine.applyLegacyLayoutMatch(muskoka))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Crisis split-screen") { CrisisSplitScreenView() }
                case .accommodations:
                    Text("Required beds: \(snapshot?.requiredBedCapacity ?? 0)")
                    Text("Secured rooms: \(snapshot?.securedHotelRoomsCount ?? 0)")
                    Text("No crew chatter surfaced on this canvas.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface.opacity(0.9))
        )
    }

    private func refresh() {
        do {
            _ = try PMMacroMatrixAggregator.refreshSnapshot(context: modelContext)
            statusMessage = "Macro matrix refreshed at \(Date().formatted(date: .omitted, time: .shortened))."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func seed() {
        do {
            try MultiUnitCrisisDispatchEngine.seedDefaultNodes(context: modelContext)
            try PMMacroMatrixAggregator.seedGreenZones(context: modelContext)
            try LocationsEquipmentMeshController.seedDemoInventory(context: modelContext)
            refresh()
            statusMessage = "Demo crisis, green zones, and RFID inventory seeded."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private enum DepartmentMacroTile: String, CaseIterable {
    case locations
    case hmw
    case transport
    case accommodations

    var systemImage: String {
        switch self {
            case .locations: "map.fill"
            case .hmw: "person.crop.rectangle.stack.fill"
            case .transport: "truck.box.fill"
            case .accommodations: "bed.double.fill"
        }
    }

    var drawerTitle: String {
        switch self {
            case .locations: "Locations detail"
            case .hmw: "HMW detail"
            case .transport: "Transport detail"
            case .accommodations: "Accommodations detail"
        }
    }
}
