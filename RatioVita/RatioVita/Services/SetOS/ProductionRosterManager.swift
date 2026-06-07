import Combine
import Foundation

struct PromotionTransaction: Identifiable, Codable, Sendable {
    var id: UUID
    var productionID: UUID
    var targetUserEmail: String
    var outgoingPosition: String
    var incomingPosition: String
    var upgradedTier: StructuralRankTier
    var effectiveTimestamp: Date
}

/// Real-time promotion / close-out handler (Sprint IIII).
@MainActor
final class ProductionRosterManager: ObservableObject {
    static let shared = ProductionRosterManager()

    @Published private(set) var lastPromotionSummary: String?

    private init() {}

    func applyPromotion(_ transaction: PromotionTransaction) {
        let coordinator = SetOSOnboardingCoordinator.shared
        guard transaction.targetUserEmail.lowercased() == coordinator.legalName.lowercased()
            || coordinator.isComplete else
        {
            lastPromotionSummary = "Promotion queued for \(transaction.targetUserEmail)"
            return
        }

        if let dept = DepartmentHierarchyRegistry.department(named: coordinator.selectedDepartmentName),
           let incoming = DepartmentHierarchyRegistry.positions(forDepartmentNamed: dept.name)
           .first(where: { $0.title == transaction.incomingPosition })
        {
            coordinator.selectedPositionTitle = incoming.title
            ConsultantSessionManager.shared.setOperationalHat(incoming.hatRole)
            MasterVaultProfileManager.shared.refreshSubscriptionsFromRoster()
            HomeScreenWidgetDataProvider.publish(from: coordinator)
            lastPromotionSummary =
                "Promoted to \(incoming.title) · Tier \(transaction.upgradedTier.displayName)"
        } else {
            lastPromotionSummary = "Unknown position \(transaction.incomingPosition)"
        }
    }

    func closeOut(email: String, at date: Date) {
        lastPromotionSummary = "Close-out \(email) · archive read-only as of \(date.formatted())"
    }
}

extension MasterVaultProfileManager {
    func refreshSubscriptionsFromRoster() {
        VitaVoiceAudioManager.shared.refreshSubscriptions()
    }
}
