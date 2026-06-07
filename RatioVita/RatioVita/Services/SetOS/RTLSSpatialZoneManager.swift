import Foundation
import SwiftData

/// Cast / crew zone transitions across receiver mesh (Sprint YYY).
@MainActor
enum RTLSSpatialZoneManager {
    static func seedDefaultReceivers(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<RTLSReceiverNode>())
        if !existing.isEmpty { return }

        let nodes = [
            RTLSReceiverNode(deviceNodeID: "STAGE_A_EXIT", physicalLocationDesc: "Soundstage A exit grid"),
            RTLSReceiverNode(deviceNodeID: "CRAFT_TRUCK_GATE", physicalLocationDesc: "Craft truck proximity gate"),
            RTLSReceiverNode(deviceNodeID: "TRAILER_HMW_02", physicalLocationDesc: "Honeywagon row 02"),
            RTLSReceiverNode(
                deviceNodeID: "SITE_MASTER_RX",
                physicalLocationDesc: "Final site master receiver",
                isMasterSiteNode: true
            ),
        ]
        for node in nodes {
            context.insert(node)
        }
        try context.save()
    }

    static func recordTransit(
        context: ModelContext,
        assetOrCrewID: String,
        toNodeID: String,
        vendorRegistry: String = "",
        notifyTAD: Bool = true
    ) throws -> ActiveTransitToken {
        let descriptor = FetchDescriptor<ActiveTransitToken>()
        let prior = try context.fetch(descriptor).first { $0.assetOrCrewID == assetOrCrewID }
        let previous = prior?.currentNodeID ?? "STAGE_A"

        if let prior {
            context.delete(prior)
        }

        let token = ActiveTransitToken(
            assetOrCrewID: assetOrCrewID,
            currentNodeID: toNodeID,
            previousNodeID: previous,
            vendorRegistry: vendorRegistry
        )
        context.insert(token)

        if notifyTAD, previous != toNodeID {
            let nodeLabel = toNodeID.replacingOccurrences(of: "_", with: " ")
            try HierarchyCommsEngine.ingest(
                context: context,
                title: "RTLS · \(assetOrCrewID)",
                body: "\(assetOrCrewID) → \(nodeLabel) (zero-chatter transit)",
                senderRole: "RTLS Mesh",
                priority: .standard
            )
        }
        try context.save()
        return token
    }

    static func quietStatusLabel(for token: ActiveTransitToken) -> String {
        "\(token.assetOrCrewID) → \(token.currentNodeID.replacingOccurrences(of: "_", with: " "))"
    }
}
