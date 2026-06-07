import SwiftData
import SwiftUI

/// Contextual pager inbox — not a generic chat clone.
struct CommsPagerInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CrewCommsNotice.createdAt, order: .reverse) private var notices: [CrewCommsNotice]

    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Focus state") {
                LabeledContent("Mode", value: HierarchyCommsEngine.activeFocusMode.rawValue)
                LabeledContent("Role", value: HierarchyCommsEngine.userOperationalRole)
                if !HierarchyCommsEngine.executiveProxyName.isEmpty {
                    LabeledContent("Executive proxy", value: HierarchyCommsEngine.executiveProxyName)
                }
            }
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Simulate delivery (test harness)") {
                Button("Standard inquiry (should queue in private focus)") {
                    simulate(priority: .standard, role: "Crew")
                }
                Button("Supervisor illness swap (DND bypass)") {
                    simulate(priority: .operationalUrgent, role: "Dept Head Supervisor")
                }
                Button("Call sheet distribute (always delivers)") {
                    simulate(priority: .callSheetDistribution, role: "2nd AD")
                }
            }
            Section("Notices (\(notices.count))") {
                if notices.isEmpty {
                    Text("No comms yet — run a simulation above.")
                        .foregroundStyle(.secondary)
                }
                ForEach(notices) { notice in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(notice.title)
                                .font(.headline)
                            Spacer()
                            if notice.wasDelivered {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "bell.slash")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(notice.body)
                            .font(.caption)
                        Text("\(notice.senderRole) · \(notice.priority.label)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Comms pager")
    }

    private func simulate(priority: CommPriorityLevel, role: String) {
        do {
            let notice = try HierarchyCommsEngine.ingest(
                context: modelContext,
                title: "Test: \(priority.label)",
                body: "Simulated payload for \(HierarchyCommsEngine.activeFocusMode.rawValue) focus.",
                senderRole: role,
                priority: priority,
                targetDepartment: "Transport"
            )
            statusMessage = notice.wasDelivered
                ? "Delivered to your device."
                : "Queued or routed to proxy — check executive lockdown settings."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

extension CommPriorityLevel {
    fileprivate var label: String {
        switch self {
            case .standard: "Standard"
            case .operationalUrgent: "Operational urgent"
            case .infrastructureCritical: "Infrastructure critical"
            case .callSheetDistribution: "Call sheet"
        }
    }
}
