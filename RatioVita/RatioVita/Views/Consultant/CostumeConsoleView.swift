import SwiftData
import SwiftUI

struct CostumeConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrailerOperationalUnit.trailerNumber) private var trailers: [TrailerOperationalUnit]
    @Query(sort: \RFIDAssetItem.itemDescription) private var assets: [RFIDAssetItem]
    @Query(sort: \TransportVehicleRun.updatedAt, order: .reverse) private var runs: [TransportVehicleRun]

    @State private var activeCharacter = "JADEN-01"
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Active look profile") {
                TextField("Character ID", text: $activeCharacter)
                let masked = ProximitySensorMaskEngine.maskedAssets(
                    activeCharacterID: activeCharacter,
                    allAssets: assets
                )
                let ignored = ProximitySensorMaskEngine.interferenceIgnored(
                    activeCharacterID: activeCharacter,
                    allAssets: assets
                )
                Text("\(masked.count) tagged items in bubble")
                Text("\(ignored.count) nearby items masked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Dressing rooms") {
                ForEach(trailers) { unit in
                    trailerRow(unit)
                }
                Button("Seed trailer row") { seedTrailer() }
            }
            Section("First looks · hawk-eye feed") {
                NavigationLink("RV · First Looks capture") {
                    FirstLooksCaptureView()
                }
                NavigationLink("Creative monitor (Designer / ACD)") {
                    CreativeMonitorFeedView()
                }
                NavigationLink("Spatial guidance to set supervisor") {
                    SpatialGuidanceConsoleView()
                }
            }
            Section("Transport intercept") {
                if let run = runs.first {
                    Text("\(run.driverName) · ETA \(run.etaMinutes)m")
                    Button("Request daily: shuttle steamer to BG holding") {
                        statusMessage = "Routed to transport captain queue (simulated)."
                    }
                } else {
                    Text("No active transport vector.")
                        .foregroundStyle(.secondary)
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("Costume mode")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed RFID look") { seedRFID() }
            }
        }
        .onAppear { UserFrictionAnalytics.trackViewOpened("CostumeConsole") }
    }

    private func trailerRow(_ unit: TrailerOperationalUnit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trailer \(unit.trailerNumber) · \(unit.assignedCastID)")
            Text(trailerStatusLabel(unit.status))
                .font(.caption)
            HStack {
                Button("Room dressed") {
                    CostumeTrailerBridge.markRoomDressed(unit: unit)
                    try? modelContext.save()
                }
                Button("Wardrobe secured") {
                    CostumeTrailerBridge.markWardrobeSecured(unit: unit)
                    try? modelContext.save()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func seedTrailer() {
        modelContext.insert(TrailerOperationalUnit(trailerNumber: "4", castID: "WILL-WRAP"))
        try? modelContext.save()
    }

    private func seedRFID() {
        modelContext.insert(RFIDAssetItem(
            rfidToken: "RFID-BR-098",
            characterID: "JADEN-01",
            description: "Brioni blazer"
        ))
        modelContext.insert(RFIDAssetItem(
            rfidToken: "RFID-POP-11",
            characterID: "POP-03",
            description: "Team cardigan (masked)"
        ))
        try? modelContext.save()
    }
}

private func trailerStatusLabel(_ state: TrailerLogisticsState) -> String {
    switch state {
        case .standby: "Standby"
        case .castEnRouteToBase: "Cast en route"
        case .roomDressedAndVerified: "Room dressed"
        case .castOccupied: "Cast in room"
        case .wardrobeSecuredPendingClearance: "Wardrobe secured"
        case .cleanAndLockActive: "Awaiting swamper"
    }
}
