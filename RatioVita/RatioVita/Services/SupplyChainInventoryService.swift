import Foundation
import SwiftData

/// Catering load lists, PM-gated cast/director specials, and auto-reload staples.
@MainActor
enum SupplyChainInventoryService {
    enum SupplyRequestOutcome: Sendable {
        case appendedToLoadList(CateringSupplyItem)
        case pendingPMApproval(CateringSupplyItem)
    }

    static func ingestRequest(
        context: ModelContext,
        title: String,
        audienceTag: String,
        isCastOrDirectorRequest: Bool,
        isPremiumSpecialty: Bool,
        onHandQuantity: Int = 0
    ) throws -> SupplyRequestOutcome {
        let isStaple = !isCastOrDirectorRequest && !isPremiumSpecialty
        let requiresPM = isCastOrDirectorRequest || isPremiumSpecialty
        let kind: SupplyListKind = requiresPM ? .buyAndLoad : .loadList
        let item = CateringSupplyItem(
            title: title,
            categoryRaw: kind.rawValue,
            isStandardWarehouseStaple: isStaple,
            requiresPMApproval: requiresPM,
            audienceTag: audienceTag,
            onHandQuantity: onHandQuantity
        )
        context.insert(item)
        try context.save()
        if requiresPM {
            return .pendingPMApproval(item)
        }
        return .appendedToLoadList(item)
    }

    static func approveForShoppers(
        context: ModelContext,
        item: CateringSupplyItem
    ) throws {
        item.requiresPMApproval = false
        item.listKind = .buyAndLoad
        item.updatedAt = .now
        try context.save()
    }

    static func evaluateAutoReload(
        context: ModelContext
    ) throws -> [CateringSupplyItem] {
        let descriptor = FetchDescriptor<CateringSupplyItem>(
            predicate: #Predicate { $0.isStandardWarehouseStaple == true }
        )
        let staples = try context.fetch(descriptor)
        return staples.filter { $0.onHandQuantity <= $0.reorderThreshold }
    }
}
