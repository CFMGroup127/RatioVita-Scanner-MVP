import SwiftData
import SwiftUI

/// Rank-scoped console tiles beyond the launcher dock (Sprint AAAA).
struct ContextualRoleDashboardView: View {
    var department: IndustryDepartmentScope?
    var tier: ConsultantTier?

    @ObservedObject private var session = ConsultantSessionManager.shared
    @ObservedObject private var vault = MasterVaultProfileManager.shared
    @ObservedObject private var honeywagon = HoneywagonTelemetryDeck.shared
    @ObservedObject private var clearances = LegalClearanceEngine.shared

    private var tiles: [ScopedWidgetRegistry.ContextualConsoleTile] {
        ScopedWidgetRegistry.tiles(
            hat: session.activeOperationalHat,
            department: department,
            consultantTier: tier,
            grant: nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Contextual console", systemImage: "person.crop.rectangle.stack.fill")
                    .font(DesignSystem.Typography.bodyEmphasized)
                Spacer()
                Text(ScopedWidgetRegistry.rankLabel(
                    hat: session.activeOperationalHat,
                    department: department,
                    consultantTier: tier
                ))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            if department == .cameraDIT || vault.activePersona?.assignedGuild == .iatse667 {
                cameraStrip
            }

            if vault.activePersona?.assignedGuild == .iatse411 {
                local411Strip
            }

            if tiles.isEmpty {
                Text("No elevated surfaces for this hat — field execution mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(tiles) { tile in
                        contextualTile(tile)
                    }
                }
            }

            if let alert = honeywagon.activeAlert,
               session.activeOperationalHat == .captain
               || session.activeOperationalHat == .coCaptain
               || session.activeOperationalHat == .pictureCar
            {
                Label(alert, systemImage: "drop.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }

    @ViewBuilder
    private func contextualTile(_ tile: ScopedWidgetRegistry.ContextualConsoleTile) -> some View {
        NavigationLink {
            destination(for: tile.surface)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: tile.systemImage)
                    .font(.title2)
                    .foregroundStyle(tile.tint)
                Text(tile.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(10)
            .background(tile.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(for surface: PerspectiveMaskingEngine.ConsoleSurface) -> some View {
        switch surface {
            case .fleetMacroGrid, .crisisSplitCommand:
                CrisisSplitScreenView()
            case .pmShowrunnerMatrix:
                PMMacroMatrixView()
            case .locationsGreenZones:
                LocationsPAHubView()
            case .firstLooksCapture:
                Text("First Looks routing — use RV · First Looks tile.")
            case .payrollVault:
                Text("Payroll vault — use RV · AP Payroll when unlocked.")
            case .driverLog, .creativeMonitorFeed, .crossUnitChatter:
                Text("Surface: \(surface.rawValue)")
        }
    }

    private var cameraStrip: some View {
        let profile = CameraDepartmentController.profile(for: session.activeOperationalHat)
        return VStack(alignment: .leading, spacing: 4) {
            Text("IATSE 667 · \(profile.displayName)")
                .font(.caption.weight(.semibold))
            Text(CameraDepartmentController.consoleSummary(profile: profile))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var local411Strip: some View {
        let caucus = Local411OfficeController.caucus(for: session.activeOperationalHat)
        return VStack(alignment: .leading, spacing: 4) {
            Text(Local411OfficeController.panelTitle(for: caucus))
                .font(.caption.weight(.semibold))
            if !clearances.assets.isEmpty {
                Text("\(clearances.assets.filter { !$0.isLegalClearanceApproved }.count) clearance(s) pending")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if caucus == .honeywagonOperator {
                Button("Simulate tank 85% alert") {
                    honeywagon.simulateCrisis()
                }
                .font(.caption)
            }
        }
    }
}
