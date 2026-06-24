import SwiftData
import SwiftUI

/// Compact global hub switcher — Personal · Ventures · Production isolation.
struct SovereignContextSwitcherBar: View {
    @ObservedObject private var context = SovereignContextManager.shared
    @Environment(\.brandAccent) private var brandAccent

    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ventureEntities: [BusinessEntity]

    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: context.activeHub.systemImage)
                    .foregroundStyle(brandAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sovereign Context")
                        .font(DesignSystem.Typography.caption.weight(.semibold))
                    Text(context.displaySubtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                hubMenu
            }

            if context.activeHub == .production, context.activeProductionID == nil {
                Text("Select a production below to enter strict isolation mode.")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.orange)
            } else {
                Text(context.isolationScopeLabel)
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
            Button {
                context.switchToPersonalHub()
            } label: {
                Label("Personal Hub", systemImage: SovereignHubKind.personal.systemImage)
            }

            Menu("Ventures Hub") {
                Button("All ventures") {
                    context.switchToVenturesHub(ventureEntityID: nil)
                }
                ForEach(ventureEntities) { entity in
                    Button(entity.legalName) {
                        context.switchToVenturesHub(ventureEntityID: entity.id)
                    }
                }
            }

            Menu("Production Mode") {
                ForEach(productions) { project in
                    Button(project.title) {
                        context.switchToProductionMode(productionID: project.id)
                    }
                }
            }
        } label: {
            Label(context.activeHub.title, systemImage: "arrow.triangle.swap")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(brandAccent.opacity(0.15)))
        }
    }
}
