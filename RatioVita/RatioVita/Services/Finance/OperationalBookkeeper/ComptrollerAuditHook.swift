import Foundation

/// Routes bookkeeping anomalies to Amina Okafor's CorporateComptroller mantle via hybrid broker.
enum ComptrollerAuditHook {
    static func notifyIfNeeded(anomalies: [String], passID: String) async {
        guard !anomalies.isEmpty else { return }

        let summary = anomalies.prefix(5).joined(separator: " · ")
        _ = await HybridAgentBrokerService.shared.submit(
            kind: .financialAnalysis,
            targetExpertName: "Amina Okafor",
            targetExpertEmail: "amina.okafor@ratiovita.com",
            productionId: SovereignContextManager.shared.activeProductionID?.uuidString,
            financialStrategy: .corporateComptroller,
            payloadSummary: "Comptroller audit [\(passID)]: \(summary)"
        )
    }
}
