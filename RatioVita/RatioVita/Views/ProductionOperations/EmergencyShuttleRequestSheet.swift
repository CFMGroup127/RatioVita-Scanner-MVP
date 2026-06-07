import SwiftData
import SwiftUI

struct EmergencyShuttleRequestSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""
    @AppStorage("com.ratiovita.payrollDisplayName") private var requesterName = ""

    @State private var geofenceNote = "Wrap location / crew parking"
    @State private var loadProfile: ShuttleLoadProfile = .solo
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your location") {
                    TextField("Where are you waiting?", text: $geofenceNote, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Gear volume") {
                    Picker("Load", selection: $loadProfile) {
                        ForEach(ShuttleLoadProfile.allCases, id: \.self) { profile in
                            Text(profile.rawValue).tag(profile)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Button {
                        submitShuttle()
                    } label: {
                        Label("Request location shuttle", systemImage: "car.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text(
                        "Flags transport captain board at highest priority. Works when walkie is out of range."
                    )
                }
                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Emergency shuttle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func submitShuttle() {
        let pid = UUID(uuidString: forensicActiveProductionID)
        do {
            let ticket = try TransportRunnerService.submitEmergencyShuttle(
                context: modelContext,
                productionProjectID: pid,
                requesterName: requesterName.isEmpty ? "Crew member" : requesterName,
                geofenceAnchor: geofenceNote,
                loadProfile: loadProfile
            )
            statusMessage = "Shuttle \(ticket.id.uuidString.prefix(8)) queued — \(ticket.requiredVehicleScale.rawValue)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
