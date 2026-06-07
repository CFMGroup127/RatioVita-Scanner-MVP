import SwiftData
import SwiftUI

/// Transport captain board — multi-leg loops and emergency shuttles.
struct TransportDispatchBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransportDispatchTicket.createdAt, order: .reverse) private var dispatches: [TransportDispatchTicket]
    @Query(sort: \RunRequestTicket.createdAt, order: .reverse) private var runTickets: [RunRequestTicket]

    var body: some View {
        List {
            Section("Emergency & active dispatch") {
                if sortedDispatches.isEmpty {
                    Text("No active transport tickets.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedDispatches) { ticket in
                    dispatchRow(ticket)
                }
            }
            Section("Pending run requests (\(pendingRuns.count))") {
                if pendingRuns.isEmpty {
                    Text("No open department runs.")
                        .foregroundStyle(.secondary)
                }
                ForEach(pendingRuns) { run in
                    runRow(run)
                }
            }
        }
        .navigationTitle("Transport board")
    }

    private var sortedDispatches: [TransportDispatchTicket] {
        TransportRunnerService.sortedDispatchBoard(tickets: dispatches)
    }

    private var pendingRuns: [RunRequestTicket] {
        runTickets.filter { !$0.isGreenLit }
    }

    private func dispatchRow(_ ticket: TransportDispatchTicket) -> some View {
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
            Text(ticket.currentGeofenceAnchor.isEmpty ? "On set" : ticket.currentGeofenceAnchor)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func runRow(_ ticket: RunRequestTicket) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ticket.requestingDepartment)
                .font(.headline)
            Text(ticket.urgency.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
