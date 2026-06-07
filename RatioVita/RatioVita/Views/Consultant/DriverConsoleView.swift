import SwiftData
import SwiftUI

/// Hands-free driver sub-console — perspective-masked by hat (Sprint SSS).
struct DriverConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = ConsultantSessionManager.shared
    @Query(sort: \TemporalRoleGrant.expirationTimestamp, order: .reverse) private var grants: [TemporalRoleGrant]

    private var activeGrant: TemporalRoleGrant? {
        grants.first { $0.isActive }
    }

    private var effectiveHat: OperationalHatRole {
        PerspectiveMaskingEngine.effectiveHat(base: session.activeOperationalHat, grant: activeGrant)
    }

    var body: some View {
        NavigationStack {
            Group {
                if PerspectiveMaskingEngine.canAccess(
                    surface: .fleetMacroGrid,
                    hat: session.activeOperationalHat,
                    grant: activeGrant
                ) {
                    transportAdminStack
                } else {
                    LiveShuttleMapView()
                }
            }
            .navigationTitle("Driver · \(effectiveHat.displayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { close() }
                }
            }
        }
        .onAppear { UserFrictionAnalytics.trackViewOpened("DriverConsole") }
        .onDisappear { closeTelemetry() }
    }

    @ViewBuilder
    private var transportAdminStack: some View {
        List {
            Section("Acting admin mode") {
                Text("Fleet macro grid unlocked via temporal grant or captain hat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                NavigationLink("Crisis split-screen") { CrisisSplitScreenView() }
                NavigationLink("Fleet monitor") { TransportMasterDashboardView() }
            }
            Section("Field log") {
                NavigationLink("Shuttle map") { LiveShuttleMapView() }
            }
        }
    }

    private func close() {
        closeTelemetry()
        dismiss()
    }

    private func closeTelemetry() {
        _ = try? UserFrictionAnalytics.trackViewClosed(
            context: modelContext,
            identifier: "DriverConsole",
            unexpectedlyClosed: false
        )
    }
}
