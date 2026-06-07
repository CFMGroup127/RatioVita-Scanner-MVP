import Combine
import Foundation

/// Trailer tank / power telemetry with threshold alerts (Sprint CCCC).
@MainActor
final class HoneywagonTelemetryDeck: ObservableObject {
    static let shared = HoneywagonTelemetryDeck()

    @Published private(set) var trailers: [HoneywagonTrailerStatus] = []
    @Published private(set) var activeAlert: String?

    private let alertThreshold = 0.80

    private init() {
        trailers = [
            HoneywagonTrailerStatus(
                id: UUID(),
                trailerUnitID: "HW-CAST-01",
                greywaterTankLevel: 0.42,
                activePowerSource: "GENERATOR_01",
                climateTemperatureCelsius: 21.5
            ),
        ]
    }

    func applySensorUpdate(_ status: HoneywagonTrailerStatus) {
        if let index = trailers.firstIndex(where: { $0.trailerUnitID == status.trailerUnitID }) {
            trailers[index] = status
        } else {
            trailers.insert(status, at: 0)
        }
        if status.greywaterTankLevel >= alertThreshold {
            activeAlert = String(
                format: "Tank %@ at %d%% · %@ · %.1f°C",
                status.trailerUnitID,
                Int(status.greywaterTankLevel * 100),
                status.activePowerSource,
                status.climateTemperatureCelsius
            )
            VitaVoiceAudioManager.shared.openSpatialBridge(
                operatorLabel: "Honeywagon · \(status.trailerUnitID)",
                responderLabel: "Pump truck · dispatched",
                incidentSummary: activeAlert ?? "Tank threshold exceeded"
            )
        } else if activeAlert?.contains(status.trailerUnitID) == true {
            activeAlert = nil
        }
    }

    func simulateCrisis(unitID: String = "HW-CAST-01", level: Double = 0.85) {
        guard var unit = trailers.first(where: { $0.trailerUnitID == unitID }) else { return }
        unit.greywaterTankLevel = level
        applySensorUpdate(unit)
    }
}
