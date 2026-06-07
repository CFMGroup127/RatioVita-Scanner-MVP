import Foundation

/// New Horizons mobile kitchen fleet ledger (Sprint EEEE).
@MainActor
enum CommercialCulinaryLedger {
    static func generatorAlert(trailerID: String, loadPercent: Double) -> String? {
        guard loadPercent >= 0.92 else { return nil }
        return "Generator surge · \(trailerID) at \(Int(loadPercent * 100))% — chef handheld only"
    }
}
