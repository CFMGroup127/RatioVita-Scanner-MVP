import SwiftData
import SwiftUI

/// Optical camera + UHF sled + RTLS simulation cockpit (WWW · XXX · YYY).
struct HardwareIngestionHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocationsEquipmentAsset.rfidToken) private var assets: [LocationsEquipmentAsset]
    @Query(sort: \ActiveTransitToken.timestamp, order: .reverse) private var transits: [ActiveTransitToken]

    @State private var truckLabel = "CUBE-02"
    @State private var vendorFilter = "VENDOR_WESTERN"
    @State private var statusMessage: String?
    @State private var radarCue: String?
    @State private var sweepResult: LocationsEquipmentMeshController.BumperSweepResult?

    var body: some View {
        List {
            Section("Intelligent capture · Vision") {
                IntelligentDocumentScannerView(
                    onCapture: { token in
                        statusMessage = "Document capture ingested: \(token)"
                    },
                    onBarcode: { value in
                        if HardwareIngestionManager.shared.ingestOptical(value) != nil {
                            statusMessage = "Barcode ingested: \(value)"
                        }
                    }
                )
                Text(
                    "Live rectangle overlay, alignment guide (yellow → green), stability + text legibility auto-shutter. Manual capture always available."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("Legacy optical · compact") {
                CameraOpticalScannerView { value in
                    if HardwareIngestionManager.shared.ingestOptical(value) != nil {
                        statusMessage = "Optical token ingested: \(value)"
                    }
                }
            }
            Section("UHF · bumper gate burst") {
                TextField("Truck label", text: $truckLabel)
                Button("Simulate 146-chair gate sweep") { runGateBurst() }
                if let sweepResult {
                    Text(sweepResult.isTruckComplete ? "Truck complete" : "\(sweepResult.totalMissing) missing")
                        .foregroundStyle(sweepResult.isTruckComplete ? .green : .orange)
                }
            }
            Section("Wearable vest · high-density pass") {
                Button("Flood 100 micro-RFID costume tags") { runVestFlood() }
            }
            Section("Slim baton · vendor isolation") {
                TextField("Vendor filter", text: $vendorFilter)
                Button("Simulate Western boot needle") { runBatonNeedle() }
                if let radarCue {
                    Text(radarCue).font(.caption).foregroundStyle(.purple)
                }
            }
            Section("RTLS · cast tracking") {
                Button("Seed receiver mesh") { seedRTLS() }
                Button("Ghost actor → Craft truck") { ghostActorTest() }
                ForEach(transits.prefix(6)) { token in
                    Text(RTLSSpatialZoneManager.quietStatusLabel(for: token))
                        .font(.caption)
                }
            }
            Section("Site clearance · master RX down") {
                Button("Validate final lock-off") { runSiteClearance() }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("Hardware ingestion")
    }

    private func runGateBurst() {
        let packets = ExternalUHFReaderBridge.simulateBumperGateBurst(chairCount: 146)
        do {
            sweepResult = try ExternalUHFReaderBridge.processBurst(
                context: modelContext,
                packets: packets,
                truckLabel: truckLabel,
                assets: assets
            )
            statusMessage = "Gate accepted \(packets.count) EPC reads."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runVestFlood() {
        let packets = WearableTransceiverBridge.simulateVestWalkthrough()
        let accepted = HardwareIngestionManager.shared.ingestBatch(packets)
        statusMessage = "Vest hub ingested \(accepted.count) tags (dedup window active)."
    }

    private func runBatonNeedle() {
        var eastern = (1...1999).map {
            HardwareSignalPacket(
                epcHexPayload: "BOOT-EASTERN-\($0)",
                hardwareProfile: .slimBatonDirectional,
                signalStrengthRSSI: -90
            )
        }
        eastern.append(
            HardwareSignalPacket(
                epcHexPayload: "BOOT-WESTERN-042",
                hardwareProfile: .slimBatonDirectional,
                signalStrengthRSSI: -34
            )
        )
        _ = HardwareIngestionManager.shared.ingestBatch(eastern)
        let target = MultiVendorAssetIsolator.isolateTarget(packets: eastern, vendorFilter: vendorFilter).last
        radarCue = MultiVendorAssetIsolator.radarAudioCue(for: target, vendorFilter: vendorFilter)
        if let target {
            AudioGuidanceFeedbackEngine.speak(radarCue ?? "")
            let proximity = HardwareIngestionManager.shared.proximityClass(for: target.signalStrengthRSSI)
            statusMessage = WearableTransceiverBridge.auditoryProximityCue(for: proximity)
        }
    }

    private func seedRTLS() {
        try? RTLSSpatialZoneManager.seedDefaultReceivers(context: modelContext)
        statusMessage = "RTLS nodes seeded."
    }

    private func ghostActorTest() {
        do {
            _ = try RTLSSpatialZoneManager.recordTransit(
                context: modelContext,
                assetOrCrewID: "CAST-01-WAYNE",
                toNodeID: "CRAFT_TRUCK_GATE"
            )
            statusMessage = "TAD-quiet update: Cast-01 → Craft truck gate."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runSiteClearance() {
        do {
            let report = try SiteClearanceValidator.validateSiteTeardown(
                context: modelContext,
                assets: assets
            )
            statusMessage = report.isSiteClear
                ? "Site clear — master receiver safe to power down."
                : "\(report.warnings.count) stranded asset(s) flagged with supervisor routing."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
