import Combine
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// RatioVita edge broker — queues local requests and relays complex work to VitaLogic expert units.
@MainActor
final class HybridAgentBrokerService: ObservableObject {
    static let shared = HybridAgentBrokerService()

    @Published private(set) var pendingRequests: [HybridAgentRequest] = []
    @Published private(set) var lastRelaySummary: String?

    private let queueURL: URL
    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        queueURL = base.appendingPathComponent("RatioVita/HybridAgentBroker", isDirectory: true)
        try? FileManager.default.createDirectory(at: queueURL, withIntermediateDirectories: true)
        pendingRequests = loadQueue()
    }

    /// Submit a complex request for VitaLogic expert processing (financial, corporate, research).
    func submit(
        kind: HybridAgentRequestKind,
        targetExpertName: String? = nil,
        targetExpertEmail: String? = nil,
        productionPUID: String? = nil,
        productionId: String? = nil,
        financialStrategy: FinancialExpertStrategy? = nil,
        payloadSummary: String
    ) async -> HybridAgentRequest {
        let mantle = SovereignContextManager.shared.activeAgentMantle
        var request = HybridAgentRequest(
            kind: kind,
            targetExpertEmail: targetExpertEmail,
            targetExpertName: targetExpertName,
            productionPUID: productionPUID,
            productionId: productionId,
            sovereignHubRaw: SovereignContextManager.shared.activeHub.rawValue,
            mantle: mantle,
            financialStrategy: financialStrategy,
            payloadSummary: payloadSummary
        )

        pendingRequests.append(request)
        persistQueue()

        let relayed = await tryCloudRelay(request)
        if let idx = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests[idx].status = relayed ? .relayedCloud : .queuedLocal
            request = pendingRequests[idx]
            persistQueue()
        }

        lastRelaySummary = relayed
            ? "Relayed \(kind.rawValue) to VitaLogic expert queue."
            : "Queued locally — expert relay deferred (offline or quota-safe mode)."
        return request
    }

    func markCompleted(requestID: String, responseSummary: String) {
        guard let idx = pendingRequests.firstIndex(where: { $0.id == requestID }) else { return }
        pendingRequests[idx].status = .completed
        pendingRequests[idx].responseSummary = responseSummary
        persistQueue()
    }

    private func persistQueue() {
        let url = queueURL.appendingPathComponent("pending-requests.json")
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadQueue() -> [HybridAgentRequest] {
        let url = queueURL.appendingPathComponent("pending-requests.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HybridAgentRequest].self, from: data) else {
            return []
        }
        return decoded
    }

    private func tryCloudRelay(_ request: HybridAgentRequest) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard RatioVitaFirebaseBootstrap.isConfigured,
              let productionId = request.productionId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !productionId.isEmpty,
              let db = RatioVitaFirebaseBootstrap.firestore() else {
            return false
        }

        let doc = db.collection("productions")
            .document(productionId)
            .collection("hybrid_agent_requests")
            .document(request.id)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let json = try JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: Any] else {
                return false
            }
            try await doc.setData(json)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
