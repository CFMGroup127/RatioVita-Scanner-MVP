import Foundation
import SwiftData

/// Bridges venture line-item allocations into the property inventory matrix.
enum AssetRegistrationBridge {

    struct RegistrationPrompt: Identifiable, Equatable {
        let id: UUID
        let lineID: UUID
        let venture: BusinessEntity
        let propertyLabel: String
        let itemTitle: String
        let purchaseAmount: Decimal
        let currencyCode: String
    }

    /// Ventures with a registered address or property-oriented naming track physical assets.
    static func ventureTracksPropertyInventory(_ entity: BusinessEntity) -> Bool {
        guard entity.isOwnedCorporation else { return false }
        let address = entity.businessAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty { return true }
        let name = entity.legalName.lowercased()
        let keywords = ["airbnb", "estate", "property", "rental", "housing", "blythe"]
        return keywords.contains { name.contains($0) }
    }

    static func propertyChecklistLabel(for entity: BusinessEntity) -> String {
        let address = entity.businessAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty { return address }
        return entity.legalName
    }

    static func prompt(
        for line: ReceiptLineItem,
        venture: BusinessEntity,
        receipt: Receipt
    ) -> RegistrationPrompt? {
        guard ventureTracksPropertyInventory(venture) else { return nil }
        let amount = ReceiptLineItemAllocationEngine.preTaxAmount(for: line)
        guard amount > 0 else { return nil }
        return RegistrationPrompt(
            id: line.id,
            lineID: line.id,
            venture: venture,
            propertyLabel: propertyChecklistLabel(for: venture),
            itemTitle: line.lineDescription,
            purchaseAmount: amount,
            currencyCode: receipt.currencyCode
        )
    }

    @MainActor
    @discardableResult
    static func registerLineItem(
        _ line: ReceiptLineItem,
        venture: BusinessEntity,
        receipt: Receipt,
        context: ModelContext
    ) throws -> EquipmentAsset {
        let amount = ReceiptLineItemAllocationEngine.preTaxAmount(for: line)
        let asset = EquipmentAsset(
            displayName: line.lineDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Capital asset"
                : line.lineDescription,
            modelName: line.lineDescription,
            serialNumber: line.serialNumber,
            purchaseDate: receipt.transactionDate ?? receipt.createdAt,
            warrantyExpiryDate: line.warrantyEndDate,
            dailyRentalRateCAD: nil,
            notes: "Registered from receipt \(receipt.merchant) · \(venture.legalName)",
            businessEntity: venture,
            sourceReceipt: receipt
        )

        context.insert(asset)
        line.glCode = line.glCode ?? "CAPITAL-ASSET"
        receipt.sourceEquipmentAsset = receipt.sourceEquipmentAsset ?? asset
        receipt.filingCabinetKindRaw = DocumentCabinet.equipment.rawValue

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: "inventory.asset.registered_from_allocation",
            title: "Venture capital asset registered",
            detail: "line:\(line.id.uuidString);asset:\(asset.id.uuidString);venture:\(venture.id.uuidString);amount:\(amount)"
        )
        try context.save()
        return asset
    }
}
