import Foundation
import SwiftData

@MainActor
enum CrossVentureLogisticsEngine {
    static func advance(
        context: ModelContext,
        ticket: CrossVentureOrderTicket,
        to status: AssetChainOfCustodyState,
        holderLabel: String
    ) throws {
        ticket.status = status
        ticket.currentHolderLabel = holderLabel
        ticket.updatedAt = .now
        try context.save()
    }

    static func statusSteps(for ticket: CrossVentureOrderTicket) -> [(String, Bool)] {
        let order: [AssetChainOfCustodyState] = [
            .preparedAtKitchen,
            .transferredToTransit,
            .arrivedAtLocationHub,
            .handedToSetPA,
            .deliveredToChair,
        ]
        let labels = [
            "176 Yonge kitchen",
            "In transit",
            "At location hub",
            "Set PA",
            "Producer chair",
        ]
        let current = ticket.status.rawValue
        return zip(order, labels).map { state, label in
            (label, state.rawValue <= current)
        }
    }
}

@MainActor
enum GeofenceNudgeController {
    static func evaluateApproach(
        etaMinutes: Int,
        destinationName: String,
        holderLabel: String
    ) -> String? {
        guard etaMinutes > 0, etaMinutes <= 20 else { return nil }
        return "Special delivery (\(holderLabel)) approaching \(destinationName) in ~\(etaMinutes) min."
    }
}
