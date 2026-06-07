import SwiftData
import SwiftUI

/// Internal wish engine — review crew tickets and publish OTA runtime flags.
struct InHouseFeedbackDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var remoteSync = RemoteConfigSynchronizer.shared

    @Query(sort: \CrewFeedbackTicket.timestamp, order: .reverse) private var tickets: [CrewFeedbackTicket]
    @Query(sort: \FrictionEventLog.createdAt, order: .reverse) private var frictionLogs: [FrictionEventLog]
    @Query(
        sort: \ExpertDiagnosticSubmission.createdAt,
        order: .reverse
    ) private var diagnostics: [ExpertDiagnosticSubmission]

    @State private var publishPettyCash = "50"
    @State private var enableTransportFlag = true
    @State private var changelog = ""

    var body: some View {
        List {
            Section {
                LabeledContent("Last sync", value: remoteSync.lastSyncedAt?.formatted() ?? "Never")
                if let msg = remoteSync.lastSyncMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Pull runtime config now") {
                    Task { await remoteSync.syncIfNeeded(trigger: "manual") }
                }
            } header: {
                Text("OTA runtime")
            }

            Section {
                TextField("Petty cash auto-approve (CAD)", text: $publishPettyCash)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                Toggle("Transport routing flag", isOn: $enableTransportFlag)
                TextField("Changelog for testers", text: $changelog, axis: .vertical)
                    .lineLimit(2...4)
                Button("Deploy live to cloud vault") {
                    deployConfig()
                }
                .buttonStyle(.borderedProminent)
            } header: {
                Text("Publish wish (hot-swap)")
            } footer: {
                Text(
                    "Writes \(RuntimeRemoteConfig.fileName) to your vault folder. Crew devices pick it up on next foreground."
                )
            }

            Section("UI friction logs (\(frictionLogs.count))") {
                if frictionLogs.isEmpty {
                    Text("No abandonment / freeze events captured yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(frictionLogs.prefix(20)) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.viewIdentifier)
                            .font(.caption.bold())
                        Text(verbatim:
                            String(
                                format: "%.1f s · closed early: %@",
                                log.interactionDuration,
                                log.wasUnexpectedlyClosed ? "yes" : "no"
                            )
                        )
                        .font(.caption2)
                        if !log.activeMissionContext.isEmpty {
                            Text(log.activeMissionContext)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Expert diagnostics (\(diagnostics.count))") {
                if diagnostics.isEmpty {
                    Text("Consultants submit via Expert program → diagnostic form.")
                        .foregroundStyle(.secondary)
                }
                ForEach(diagnostics.prefix(15)) { diag in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diag.anonymousToken)
                            .font(.caption.monospaced())
                        Text(diag.frictionNotes)
                            .font(.caption)
                    }
                }
            }

            Section("Open feedback (\(openCount))") {
                if tickets.isEmpty {
                    Text("No tickets yet — testers shake device (iOS) or press ⌘⇧F (Mac).")
                        .foregroundStyle(.secondary)
                }
                ForEach(tickets) { ticket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(ticket.originatingDepartment)
                                .font(.headline)
                            Spacer()
                            if ticket.isExecuted {
                                Text("Granted")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(ticket.userNotes)
                            .font(.subheadline)
                        Text("\(ticket.currentViewContext) · \(ticket.devicePlatform)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(ticket.timestamp.formatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !ticket.isExecuted {
                            Button("Mark executed") {
                                ticket.isExecuted = true
                                try? modelContext.save()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Feedback & OTA")
        .task {
            await remoteSync.syncIfNeeded(trigger: "dashboard")
        }
    }

    private var openCount: Int {
        tickets.filter { !$0.isExecuted }.count
    }

    private func deployConfig() {
        let petty = Double(publishPettyCash) ?? 50
        let config = RuntimeRemoteConfig(
            schemaVersion: (remoteSync.activeConfig.schemaVersion) + 1,
            deployedAt: ISO8601DateFormatter().string(from: .now),
            changelog: changelog.isEmpty ? "In-house deploy" : changelog,
            featureFlags: [
                SovereignFeatureFlags.transportRunnerRoutingKey: enableTransportFlag,
            ],
            pettyCashAutoApproveCAD: petty,
            experimentalViewFlags: [
                "approvalsInboxProminent": true,
            ]
        )
        do {
            _ = try remoteSync.publishToCloudVault(config)
            changelog = ""
        } catch {
            remoteSync.noteSyncMessage(error.localizedDescription)
        }
    }
}
