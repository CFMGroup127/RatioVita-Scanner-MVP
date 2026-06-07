import SwiftData
import SwiftUI

struct TemporalAuthHandoffView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TemporalRoleGrant.expirationTimestamp, order: .reverse) private var grants: [TemporalRoleGrant]

    @State private var targetToken = "DRV-STEPUP-01"
    @State private var role: OperationalHatRole = .captain
    @State private var unit: ProductionUnitNode = .mainUnitAlgonquin
    @State private var hours: Double = 24
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Issue 24-hour handoff") {
                TextField("Crew token", text: $targetToken)
                Picker("Temporary hat", selection: $role) {
                    ForEach([OperationalHatRole.captain, .coCaptain, .coordinator], id: \.self) { hat in
                        Text(hat.displayName).tag(hat)
                    }
                }
                Picker("Unit", selection: $unit) {
                    ForEach(ProductionUnitNode.allCases) { node in
                        Text(node.displayName).tag(node)
                    }
                }
                Stepper("Duration: \(Int(hours))h", value: $hours, in: 1...72, step: 1)
                Button("Grant acting permissions") { issue() }
            }
            Section("Active grants") {
                if grants.filter(\.isActive).isEmpty {
                    Text("No active temporal tokens.")
                        .foregroundStyle(.secondary)
                }
                ForEach(grants.filter(\.isActive)) { grant in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(grant.userToken).font(.caption.monospaced())
                        Text("\(grant.temporaryRole.displayName) · \(grant.unitNode.displayName)")
                        Text(TemporalAuthorizationService.formattedRemaining(grant))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("Temporal auth")
        .onAppear {
            TemporalAuthorizationService.pruneExpired(context: modelContext)
        }
    }

    private func issue() {
        do {
            _ = try TemporalAuthorizationService.issueGrant(
                context: modelContext,
                userToken: targetToken,
                temporaryRole: role,
                unit: unit,
                durationHours: hours,
                issuedBy: "CAPTAIN-HANDOFF"
            )
            statusMessage = "Grant active — launcher expands at next open."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
