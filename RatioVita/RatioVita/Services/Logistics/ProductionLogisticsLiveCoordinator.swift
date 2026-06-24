import Combine
import Foundation

/// App-wide hook — keeps the logistical guardian Firestore listeners aligned with the active production.
@MainActor
final class ProductionLogisticsLiveCoordinator: ObservableObject {
    static let shared = ProductionLogisticsLiveCoordinator()

    @Published private(set) var activeProductionId: String = ""
    @Published private(set) var isFirebaseReady = false

    private init() {}

    func syncActiveProduction(productionId: String, callSheetId: String? = nil) {
        RatioVitaFirebaseBootstrap.ensureConfigured()
        let trimmed = productionId.trimmingCharacters(in: .whitespacesAndNewlines)
        activeProductionId = trimmed
        isFirebaseReady = RatioVitaFirebaseBootstrap.isConfigured

        guard isFirebaseReady, !trimmed.isEmpty else {
            TransitGuardianStreamService.shared.stopListening()
            return
        }

        let sheet = callSheetId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSheet = (sheet?.isEmpty == false) ? sheet : nil
        TransitGuardianStreamService.shared.startListening(
            productionId: trimmed,
            callSheetId: resolvedSheet
        )
    }
}
