import Foundation
import SwiftData

/// Cross-unit driver apportionment + legacy layout templates (Sprint SSS).
@MainActor
enum MultiUnitCrisisDispatchEngine {
    static let muskokaLegacyLayoutID = "MUSKOKA_ZONE3_2024_SHORT"

    static func seedDefaultNodes(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ProductionUnitCrisisNode>())
        if !existing.isEmpty { return }

        let algonquin = ProductionUnitCrisisNode(
            unit: .mainUnitAlgonquin,
            crisisTier: .operationalWarning,
            statusLabel: "Stroll in the park — surplus drivers available",
            fleetTrailerCount: 8
        )
        algonquin.surplusDriverTokens = ["DRV-JESS-A", "DRV-JESS-B", "DRV-JESS-C"]

        let muskoka = ProductionUnitCrisisNode(
            unit: .secondUnitMuskoka,
            crisisTier: .activeEvacuation,
            statusLabel: "Wildfire evac prep — 30 tractor-trailers staged",
            fleetTrailerCount: 30,
            legacyLayoutTemplateID: muskokaLegacyLayoutID
        )

        context.insert(algonquin)
        context.insert(muskoka)
        try context.save()
    }

    static func apportionDrivers(
        context: ModelContext,
        from source: ProductionUnitNode,
        to destination: ProductionUnitNode,
        driverTokens: [String]
    ) throws {
        let nodes = try context.fetch(FetchDescriptor<ProductionUnitCrisisNode>())
        guard let src = nodes.first(where: { $0.unitNode == source }),
              let dst = nodes.first(where: { $0.unitNode == destination }) else { return }

        var surplus = src.surplusDriverTokens
        surplus.removeAll { driverTokens.contains($0) }
        src.surplusDriverTokens = surplus

        var inbound = dst.inboundDriverTokens
        for token in driverTokens where !inbound.contains(token) {
            inbound.append(token)
        }
        dst.inboundDriverTokens = inbound
        dst.statusLabel = "Ingesting \(driverTokens.count) driver(s) from \(source.displayName)"
        dst.updatedAt = .now
        src.updatedAt = .now

        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Delta apportionment",
            body: "\(driverTokens.joined(separator: ", ")) rerouted \(source.displayName) → \(destination.displayName).",
            senderRole: "Transport Coordinator",
            priority: .operationalUrgent
        )
        try context.save()
    }

    static func applyLegacyLayoutMatch(_ node: ProductionUnitCrisisNode) -> String {
        guard node.legacyLayoutTemplateID == muskokaLegacyLayoutID else {
            return "No legacy template on file."
        }
        return "Zone 3 layout (Jessica + TAD 2024 short) — 30 trailer plots + honeywagon grid restored."
    }
}
