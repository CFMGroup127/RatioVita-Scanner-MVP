import Foundation
import SwiftData

/// Predictive utility dispatch during evacuation stress (Sprint TTT).
@MainActor
enum PredictiveDispatchEngine {
    struct StressTelemetry: Sendable {
        var workerToken: String
        var velocityMetersPerMinute: Double
        var inclineGrade: Double
        var loadAnomalyScore: Double
    }

    struct DispatchAssignment: Identifiable, Sendable {
        var id: String { workerToken + vehicleLabel }
        var workerToken: String
        var vehicleLabel: String
        var routeHint: String
        var automated: Bool
    }

    static func shouldAutoDispatch(
        telemetry: StressTelemetry,
        crisisTier: CrisisScaleTier
    ) -> Bool {
        guard crisisTier == .activeEvacuation else { return false }
        return telemetry.velocityMetersPerMinute < 12
            && telemetry.inclineGrade > 0.08
            && telemetry.loadAnomalyScore > 0.6
    }

    static func assignInterceptVehicle(
        context: ModelContext,
        telemetry: StressTelemetry,
        unit: ProductionUnitNode
    ) throws -> DispatchAssignment? {
        guard shouldAutoDispatch(telemetry: telemetry, crisisTier: unit.defaultCrisisTier) else {
            return nil
        }
        let assignment = DispatchAssignment(
            workerToken: telemetry.workerToken,
            vehicleLabel: "UTIL-4x4-\(unit.rawValue.suffix(4))",
            routeHint: "East trail exit · high-capacity gear transfer",
            automated: true
        )
        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Vita predictive dispatch",
            body: "\(assignment.vehicleLabel) → \(telemetry.workerToken). \(assignment.routeHint)",
            senderRole: "Predictive Dispatch",
            priority: .infrastructureCritical
        )
        try context.save()
        return assignment
    }
}
