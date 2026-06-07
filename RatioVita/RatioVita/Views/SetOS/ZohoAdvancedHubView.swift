import SwiftUI

/// VitaLogic advanced Zoho orchestration cockpit (Sprint GGGG).
struct ZohoAdvancedHubView: View {
    @ObservedObject private var orchestrator = ZohoEcosystemOrchestrator.shared
    @ObservedObject private var roster = CrewRosterSyncEngine.shared
    @ObservedObject private var vault = MasterVaultProfileManager.shared

    @State private var fuelAmount = "12500"
    @State private var statusNote: String?

    var body: some View {
        List {
            Section("Active tenant") {
                Text(vault.activeMacroDomain.displayName)
                Text("Packets are isolated per `MacroTenantDomain` before Zoho API routing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Module sync status") {
                ForEach(orchestrator.syncStatuses, id: \.module.rawValue) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.module.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(status.lastMessage)
                            .font(.caption)
                        if status.lastSync != .distantPast {
                            Text("Last sync \(status.lastSync.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Expense pipeline · Books") {
                TextField("Fuel amount (cents)", text: $fuelAmount)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                Button("Simulate driver fuel voucher") {
                    let cents = Int(fuelAmount) ?? 0
                    ZohoExpensePipeline.submitFuelVoucher(
                        driverToken: "DRV-UNIT-2",
                        amountCents: cents
                    )
                    statusNote = "Expense queued with transport fringe multiplier."
                }
                Button("Simulate costume rental approval") {
                    ZohoExpensePipeline.submitRentalApproval(
                        department: .costume,
                        assetLabel: "Western boot rack",
                        amountCents: 48000
                    )
                    statusNote = "Rental expense packet pushed to Books."
                }
            }

            Section("Roster sync · People / Shifts") {
                Button("Inject department wrap batch") {
                    roster.compileWrapBatch(
                        department: .transport,
                        crewTokens: ["DRV-01", "DRV-02", "SWP-01"],
                        gateCheckIns: 3,
                        voiceLogEntries: VitaVoiceAudioManager.shared.recentPackets.count
                    )
                    statusNote = "Auto-timecard drafts compiled from telemetry."
                }
                ForEach(roster.pendingSignOff) { draft in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.crewToken)
                            .font(.caption.weight(.semibold))
                        Text(
                            "\(draft.departmentLabel) · \(draft.hoursComputed, format: .number.precision(.fractionLength(2))) h · gates \(draft.gateCheckIns)"
                        )
                        .font(.caption2)
                        Button("Confirm & push to Zoho") {
                            roster.confirmDraft(id: draft.id)
                        }
                        .font(.caption)
                    }
                }
            }

            Section("CRM / Creator") {
                Button("Push script requisition token") {
                    orchestrator.enqueue(
                        module: .crmCreator,
                        payload: [
                            "asset": "Period wardrobe surge",
                            "script_page": "Pink rev · 42",
                        ]
                    )
                    statusNote = "Creator ledger packet enqueued."
                }
            }

            Section("Outbound queue") {
                ForEach(orchestrator.outboundQueue.prefix(8)) { packet in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(packet.targetModule.displayName)
                            .font(.caption.weight(.semibold))
                        Text(packet.recordPayloadHex.prefix(24) + "…")
                            .font(.caption2.monospaced())
                        Text(packet.boundTenantDomain.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let statusNote {
                Section { Text(statusNote).font(.caption) }
            }

            Section {
                Text("Vault file import (Phase 1) remains in Settings → Zoho inbox paths.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Zoho · VitaLogic")
    }
}
