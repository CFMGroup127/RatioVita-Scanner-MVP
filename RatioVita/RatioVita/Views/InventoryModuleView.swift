import SwiftData
import SwiftUI

/// **Inventory & Asset Sentinel** — gear registry linked to corporate / shadow entities.
struct InventoryModuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EquipmentAsset.displayName) private var assets: [EquipmentAsset]
    @Query(sort: \BusinessEntity.legalName) private var entities: [BusinessEntity]

    @State private var showAddAsset = false

    private var expiringSoonCount: Int {
        assets.filter(\.isWarrantyExpiringSoon).count
    }

    var body: some View {
        NavigationStack {
            List {
                if expiringSoonCount > 0 {
                    Section {
                        Label(
                            "\(expiringSoonCount) warranty(ies) expiring within 30 days",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                }
                Section {
                    HStack {
                        Text("Gear registry")
                        Spacer(minLength: 0)
                        RatioVitaHint(term: .shadowRegistry)
                        RatioVitaHint(term: .fixedAssets)
                        RatioVitaHint(term: .depreciation)
                    }
                }
                if assets.isEmpty {
                    ContentUnavailableView(
                        "No assets yet",
                        systemImage: "shippingbox",
                        description: Text(
                            "Convert a receipt in Review, or add laptops, trucks, and kit with daily rental rates."
                        )
                    )
                } else {
                    ForEach(assets) { asset in
                        NavigationLink {
                            EquipmentAssetDetailView(asset: asset)
                        } label: {
                            assetRow(asset)
                        }
                    }
                    .onDelete(perform: deleteAssets)
                }
            }
            .navigationTitle("Inventory")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddAsset = true
                        } label: {
                            Label("Add asset", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddAsset) {
                    EquipmentAssetEditorSheet(entities: entities, onDismiss: { showAddAsset = false })
                }
        }
    }

    @ViewBuilder
    private func assetRow(_ asset: EquipmentAsset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(asset.displayName)
                    .font(.headline)
                if asset.isWarrantyExpiringSoon {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
            if let serial = asset.serialNumber, !serial.isEmpty {
                Text("S/N \(serial)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let rate = asset.dailyRentalRateCAD {
                Text(verbatim: "$\(rate.formatted(.number.precision(.fractionLength(2))))/day kit rate")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func deleteAssets(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(assets[i])
        }
        try? modelContext.save()
    }
}

private struct EquipmentAssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""
    @Query(sort: \ProductionProject.title) private var productions: [ProductionProject]
    @Bindable var asset: EquipmentAsset

    private var activeProject: ProductionProject? {
        guard let uuid = UUID(uuidString: forensicActiveProductionID) else { return nil }
        return productions.first { $0.id == uuid }
    }

    var body: some View {
        Form {
            Section("Asset") {
                LabeledContent("Name", value: asset.displayName)
                if let m = asset.modelName, !m.isEmpty { LabeledContent("Model", value: m) }
                if let s = asset.serialNumber, !s.isEmpty { LabeledContent("Serial", value: s) }
            }
            Section("Dates") {
                if let p = asset.purchaseDate {
                    LabeledContent("Purchased", value: p.formatted(date: .abbreviated, time: .omitted))
                }
                if let w = asset.warrantyExpiryDate {
                    LabeledContent("Warranty ends", value: w.formatted(date: .abbreviated, time: .omitted))
                }
            }
            if let rate = asset.dailyRentalRateCAD {
                Section("Rental") {
                    LabeledContent("Daily rate (CAD)", value: "\(rate)")
                }
            }
            if let project = activeProject {
                Section("Labor Sentinel checkout") {
                    LabeledContent("Active show", value: project.title)
                    Button {
                        let kind = ProductionKitDeviceKind.infer(from: asset.displayName)
                        _ = try? KitCheckoutService.checkout(
                            asset: asset,
                            to: project,
                            kind: kind,
                            context: modelContext
                        )
                    } label: {
                        Label("Check out to show", systemImage: "link")
                    }
                }
            } else {
                Section {
                    Text("Pin an active production on Home to check out gear for EP kit lines.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(asset.displayName)
    }
}

private struct EquipmentAssetEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var entities: [BusinessEntity]
    var onDismiss: () -> Void

    @State private var name = ""
    @State private var serial = ""
    @State private var dailyRate = ""
    @State private var selectedEntityID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Display name", text: $name)
                TextField("Serial number", text: $serial)
                TextField("Daily rental (CAD)", text: $dailyRate)
                Picker("Business entity", selection: $selectedEntityID) {
                    Text("None").tag(UUID?.none)
                    ForEach(entities) { e in
                        Text(e.legalName).tag(Optional(e.id))
                    }
                }
            }
            .navigationTitle("New asset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entity = entities.first { $0.id == selectedEntityID }
        let rate = Decimal(string: dailyRate.replacingOccurrences(of: ",", with: "."))
        let asset = EquipmentAsset(
            displayName: trimmed,
            serialNumber: serial.nilIfEmpty,
            dailyRentalRateCAD: rate,
            businessEntity: entity
        )
        modelContext.insert(asset)
        try? modelContext.save()
        onDismiss()
        dismiss()
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
