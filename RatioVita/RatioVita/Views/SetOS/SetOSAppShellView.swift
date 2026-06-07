import SwiftUI

/// Dynamic home shell — dock + contextual rank dashboard (Sprint DDDD).
struct SetOSAppShellView: View {
    var department: IndustryDepartmentScope?
    var tier: ConsultantTier?
    var onLaunch: (LauncherModuleIntent) -> Void

    @ObservedObject private var vault = MasterVaultProfileManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if vault.activeMacroDomain != .technicalCrews {
                tenantBanner
            }
            VoiceCommsOverlayView()
            DepartmentLauncherDockView(
                department: department,
                tier: tier,
                onLaunch: onLaunch
            )
            ContextualRoleDashboardView(department: department, tier: tier)
        }
    }

    private var tenantBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.columns.fill")
            Text(vault.activeMacroDomain.displayName)
                .font(.caption.weight(.semibold))
            Spacer()
            Text("Insulated tenant view")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
