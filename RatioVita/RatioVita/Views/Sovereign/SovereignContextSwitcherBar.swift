import SwiftData
import SwiftUI

/// Compact global hub switcher — Personal · Ventures · Production isolation.
struct SovereignContextSwitcherBar: View {
    @ObservedObject private var context = SovereignContextManager.shared
    @Environment(\.brandAccent) private var brandAccent

    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ventureEntities: [BusinessEntity]

    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]

    private var activeHubTitle: String { context.activeHub.title }
    private var activeHubIcon: String { context.activeHub.systemImage }
    private var subtitleText: String { context.displaySubtitle }
    private var scopeLabel: String { context.isolationScopeLabel }
    private var needsProductionPin: Bool {
        context.activeHub == .production && context.activeProductionID == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: activeHubIcon)
                    .foregroundStyle(brandAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sovereign Context")
                        .font(DesignSystem.Typography.caption.weight(.semibold))
                    Text(subtitleText)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                hubMenu
            }

            if needsProductionPin {
                Text("Select a production below to enter strict isolation mode.")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.orange)
            } else {
                Text(scopeLabel)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }

    private var hubMenu: some View {
        Menu {
            Section("Personal") {
                Button {
                    scheduleHubSwitch { context.switchToPersonalHub() }
                } label: {
                    Label("Personal Hub", systemImage: SovereignHubKind.personal.systemImage)
                }
            }

            Section("Ventures Hub") {
                Button("All ventures") {
                    scheduleHubSwitch { context.switchToVenturesHub(ventureEntityID: nil) }
                }
                ForEach(ventureEntities) { entity in
                    Button(entity.legalName) {
                        scheduleHubSwitch { context.switchToVenturesHub(ventureEntityID: entity.id) }
                    }
                }
            }

            Section("Production Mode") {
                ForEach(productions) { project in
                    Button(project.title) {
                        scheduleHubSwitch { context.switchToProductionMode(productionID: project.id) }
                    }
                }
            }
        } label: {
            Label(activeHubTitle, systemImage: "arrow.triangle.swap")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(brandAccent.opacity(0.15)))
        }
        .menuStyle(.borderlessButton)
        .id(activeHubTitle)
    }

    /// Avoid mutating global `@Published` state during nested menu layout passes (macOS submenu storm).
    private func scheduleHubSwitch(_ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
}
