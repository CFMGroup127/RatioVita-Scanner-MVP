import SwiftData
import SwiftUI

/// Labor Sentinel: check out inventory assets to the active show for EP kit lines.
struct KitCheckoutLaborSection: View {
    @Environment(\.modelContext) private var modelContext
    var project: ProductionProject
    var days: [CrewTimecardDay]

    @Query(sort: \EquipmentAsset.displayName) private var assets: [EquipmentAsset]

    private var activeCheckouts: [ProductionKitCheckout] {
        project.kitCheckouts.filter(\.isActive)
    }

    var body: some View {
        if activeCheckouts.isEmpty {
            Text("No gear checked out to this show.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(activeCheckouts, id: \.id) { co in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(co.equipmentAsset?.displayName ?? co.deviceKind.epOtherRatesLabel)
                            .font(.subheadline.weight(.medium))
                        Text(co.deviceKind.epOtherRatesLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check in") {
                        try? KitCheckoutService.checkIn(co, context: modelContext)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        Menu {
            ForEach(assets) { asset in
                Button(asset.displayName) {
                    checkout(asset)
                }
            }
        } label: {
            Label("Check out asset from inventory", systemImage: "shippingbox")
        }
        .disabled(assets.isEmpty)

        Button {
            try? KitCheckoutService.applyActiveCheckoutsToCrewDays(
                project: project,
                days: days,
                context: modelContext
            )
        } label: {
            Label("Apply kit to all crew days", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(days.isEmpty || activeCheckouts.isEmpty)
    }

    private func checkout(_ asset: EquipmentAsset) {
        let kind = ProductionKitDeviceKind.infer(from: asset.displayName)
        _ = try? KitCheckoutService.checkout(asset: asset, to: project, kind: kind, context: modelContext)
    }
}
