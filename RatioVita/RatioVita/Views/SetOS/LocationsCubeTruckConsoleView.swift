import SwiftData
import SwiftUI

/// Locations PA — cube truck bumper RFID sweep (Sprint VVV).
struct LocationsCubeTruckConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocationsEquipmentAsset.rfidToken) private var assets: [LocationsEquipmentAsset]
    @Query(sort: \LocationsTruckManifest.truckLabel) private var manifests: [LocationsTruckManifest]

    @State private var truckLabel = "CUBE-02"
    @State private var sweepResult: LocationsEquipmentMeshController.BumperSweepResult?
    @State private var statusMessage: String?

    private var manifest: LocationsTruckManifest? {
        manifests.first { $0.truckLabel == truckLabel }
            ?? manifests.first
    }

    var body: some View {
        List {
            Section("Bumper sweep · \(truckLabel)") {
                TextField("Cube truck label", text: $truckLabel)
                Button("Seed rental manifest + 150 chairs") { seed() }
                Button("Run passive bumper sweep") { runSweep() }
                Button("UHF gate burst (146 chairs)") { runUHFBurst() }
                if let sweepResult {
                    if sweepResult.isTruckComplete {
                        Label("Truck complete", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    } else {
                        Label("\(sweepResult.totalMissing) items missing", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.headline)
                    }
                }
            }
            if let sweepResult {
                Section("Load manifest") {
                    ForEach(sweepResult.lines) { line in
                        manifestRow(line)
                    }
                }
                if !sweepResult.missingAssets.isEmpty {
                    Section("RFID last-seen clusters") {
                        ForEach(sweepResult.missingAssets) { asset in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.rfidToken)
                                    .font(.caption.monospaced())
                                Text(asset.assetType.displayName)
                                Text(asset.lastKnownZone.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("Cube truck gate")
        .onAppear { UserFrictionAnalytics.trackViewOpened("LocationsCubeTruck") }
    }

    @ViewBuilder
    private func manifestRow(_ line: LocationsEquipmentMeshController.ManifestLineResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: line.isComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(line.isComplete ? .green : .red)
                Text(line.assetType.displayName)
                    .font(.headline)
                Spacer()
                Text("\(line.detectedCount) / \(line.expectedCount)")
                    .font(.caption.monospaced())
            }
            Text(line.vendorSource)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let guidance = line.recoveryGuidance {
                Text(guidance)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func seed() {
        do {
            try LocationsEquipmentMeshController.seedDemoInventory(
                context: modelContext,
                truckLabel: truckLabel,
                omitChairCount: 4
            )
            if manifests.first(where: { $0.truckLabel == truckLabel }) == nil {
                modelContext.insert(LocationsEquipmentMeshController.defaultCubeManifest(truckLabel: truckLabel))
                try modelContext.save()
            }
            statusMessage = "Manifest + tagged inventory seeded (4 chairs left at Satellite BG)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runUHFBurst() {
        let packets = ExternalUHFReaderBridge.simulateBumperGateBurst(chairCount: 146)
        do {
            sweepResult = try ExternalUHFReaderBridge.processBurst(
                context: modelContext,
                packets: packets,
                truckLabel: truckLabel,
                assets: assets
            )
            statusMessage = "UHF gate burst ingested \(packets.count) EPC reads."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runSweep() {
        guard let manifest else {
            statusMessage = "Seed manifest first."
            return
        }
        sweepResult = LocationsEquipmentMeshController.performBumperSweep(
            manifest: manifest,
            assets: assets,
            truckLabel: truckLabel
        )
        statusMessage = sweepResult?.isTruckComplete == true
            ? "Green checkmark — \(truckLabel) complete."
            : "Red warning — recovery clusters pinned."
    }
}
