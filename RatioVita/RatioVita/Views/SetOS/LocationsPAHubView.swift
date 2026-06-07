import SwiftData
import SwiftUI

/// Locations department PA command surface (Sprint VVV).
struct LocationsPAHubView: View {
    @Query(sort: \LocationsGreenZone.zoneName) private var greenZones: [LocationsGreenZone]

    var body: some View {
        List {
            Section("Today's plot checklist (6-person crew)") {
                plotRow("Main BG holding", systemImage: "person.3.fill")
                plotRow("Satellite BG holding", systemImage: "person.2.fill")
                plotRow("Crew lunch area", systemImage: "fork.knife")
                plotRow("Tent row on set", systemImage: "tent.fill")
                plotRow("Garbage / butt-bin distribution", systemImage: "trash.fill")
                plotRow("Signage + traffic arrows", systemImage: "signpost.right.fill")
            }
            Section("Wrap load-up") {
                NavigationLink("Cube truck bumper sweep") {
                    LocationsCubeTruckConsoleView()
                }
                NavigationLink("Hardware ingestion (camera + UHF + RTLS)") {
                    HardwareIngestionHubView()
                }
                Text("RFID gate sweep replaces hand-counting 150 rental chairs in the dark.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Green zones · hotel crosswalk") {
                if greenZones.isEmpty {
                    Text("PM macro matrix can seed Tristan's zone list.")
                        .foregroundStyle(.secondary)
                }
                ForEach(greenZones) { zone in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(zone.zoneName)
                                .font(.headline)
                            if zone.isFavourable {
                                Text("Favourable")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("Rooms secured: \(zone.securedHotelRooms) / \(zone.requiredBedCapacity) beds")
                            .font(.caption)
                        if !zone.overheadNotes.isEmpty {
                            Text(zone.overheadNotes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Locations desk")
        .onAppear { UserFrictionAnalytics.trackViewOpened("LocationsPAHub") }
    }

    private func plotRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
    }
}
