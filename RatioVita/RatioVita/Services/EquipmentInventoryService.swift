import Foundation
import SwiftData

@MainActor
enum EquipmentInventoryService {
    static func createAsset(
        from receipt: Receipt,
        context: ModelContext
    ) throws -> EquipmentAsset {
        let name = receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = name.isEmpty ? "Equipment" : name
        let serial = receipt.lineItems
            .compactMap(\.serialNumber)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let modelFromLine = receipt.lineItems.first?.lineDescription

        let asset = EquipmentAsset(
            displayName: display,
            modelName: modelFromLine,
            serialNumber: serial,
            purchaseDate: receipt.transactionDate ?? receipt.createdAt,
            warrantyExpiryDate: nil,
            dailyRentalRateCAD: nil,
            notes: "Converted from receipt \(receipt.id.uuidString.prefix(8))",
            businessEntity: nil,
            preliminaryBusinessEntity: receipt.preliminaryBusinessEntity,
            sourceReceipt: receipt
        )
        if asset.businessEntity == nil, asset.preliminaryBusinessEntity == nil,
           let payee = receipt.payeeName?.trimmingCharacters(in: .whitespacesAndNewlines), !payee.isEmpty
        {
            if let shadow = ShadowRegistryService.matchingShadow(forLegalName: payee, context: context) {
                asset.preliminaryBusinessEntity = shadow
            }
        }
        context.insert(asset)
        receipt.sourceEquipmentAsset = asset
        receipt.filingCabinetKindRaw = DocumentCabinet.equipment.rawValue
        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: "inventory.asset.created",
            title: "Receipt converted to equipment asset",
            detail: "rid:\(receipt.id.uuidString);asset:\(asset.id.uuidString)"
        )
        return asset
    }
}
