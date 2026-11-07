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
    @Published private(set) var lastRelayError: String?
    @Published private(set) var responses: [HybridAgentResponse] = []
    @Published private(set) var latestResponse: HybridAgentResponse?
    @Published private(set) var responseBanner: HybridAgentResponse?
    @Published private(set) var listenerError: String?

    private let queueURL: URL
    private var activeResponseProductionID: String?
    private var hasReceivedInitialResponseSnapshot = false
    #if canImport(FirebaseFirestore)
    private var responseListener: ListenerRegistration?
    #endif

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

        let relayed: Bool
        do {
            relayed = try await tryCloudRelay(request)
            lastRelayError = nil
        } catch {
            relayed = false
            lastRelayError = error.localizedDescription
        }
        if let idx = pendingRequests.firstIndex(where: { $0.id == request.id }) {
            pendingRequests[idx].status = relayed ? .relayedCloud : .queuedLocal
            request = pendingRequests[idx]
            persistQueue()
        }

        lastRelaySummary = relayed
            ? "Relayed \(kind.rawValue) to VitaLogic expert queue."
            : lastRelayError.map { "Queued locally — cloud relay failed: \($0)" }
            ?? "Queued locally — expert relay deferred (offline or quota-safe mode)."
        return request
    }

    func markCompleted(requestID: String, responseSummary: String) {
        guard let idx = pendingRequests.firstIndex(where: { $0.id == requestID }) else { return }
        pendingRequests[idx].status = .completed
        pendingRequests[idx].responseSummary = responseSummary
        persistQueue()
    }

    func syncActiveProduction(productionId: String) {
        let productionId = productionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !productionId.isEmpty else {
            stopListening()
            return
        }
        guard activeResponseProductionID != productionId || responseListener == nil else { return }

        stopListening()
        activeResponseProductionID = productionId
        #if canImport(FirebaseFirestore)
        guard RatioVitaFirebaseBootstrap.isConfigured,
              let db = RatioVitaFirebaseBootstrap.firestore() else
        {
            listenerError = "Firestore is not configured; expert responses are unavailable."
            return
        }

        responseListener = db.collection("productions")
            .document(productionId)
            .collection("hybrid_agent_responses")
            .whereField("status", isEqualTo: HybridAgentRequestStatus.completed.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                _Concurrency.Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.listenerError = "Could not listen for expert responses: \(error.localizedDescription)"
                        return
                    }
                    guard let snapshot else {
                        self.listenerError = "Firestore returned an empty expert response snapshot."
                        return
                    }

                    let isInitialSnapshot = !self.hasReceivedInitialResponseSnapshot
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    var decodedResponses: [HybridAgentResponse] = []
                    var decodingError: String?
                    for document in snapshot.documents {
                        do {
                            let data = try JSONSerialization.data(withJSONObject: document.data())
                            let response = try decoder.decode(HybridAgentResponse.self, from: data)
                            guard response.id == document.documentID,
                                  response.productionId == productionId else
                            {
                                throw HybridAgentResponseError.documentIdentityMismatch
                            }
                            decodedResponses.append(response)
                        } catch {
                            decodingError = "Could not decode expert response \(document.documentID): \(error.localizedDescription)"
                        }
                    }

                    self.responses = decodedResponses.sorted { $0.completedAt > $1.completedAt }
                    self.latestResponse = self.responses.first
                    self.listenerError = decodingError
                    var didUpdatePendingRequests = false
                    for response in decodedResponses {
                        guard let index = self.pendingRequests.firstIndex(where: { $0.id == response.id }) else { continue }
                        self.pendingRequests[index].status = response.status
                        self.pendingRequests[index].responseSummary = response.responseSummary
                        didUpdatePendingRequests = true
                    }
                    if didUpdatePendingRequests {
                        self.persistQueue()
                    }
                    if !isInitialSnapshot {
                        for change in snapshot.documentChanges where change.type == .added {
                            if let response = decodedResponses.first(where: { $0.id == change.document.documentID }) {
                                self.responseBanner = response
                            }
                        }
                    }
                    self.hasReceivedInitialResponseSnapshot = true
                }
            }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        responseListener?.remove()
        responseListener = nil
        #endif
        activeResponseProductionID = nil
        hasReceivedInitialResponseSnapshot = false
        responses = []
        latestResponse = nil
        responseBanner = nil
        listenerError = nil
    }

    func dismissResponseBanner() {
        responseBanner = nil
    }

    func dismissListenerError() {
        listenerError = nil
    }

    func dismissRelayError() {
        lastRelayError = nil
    }

    private func persistQueue() {
        let url = queueURL.appendingPathComponent("pending-requests.json")
        guard let data = try? JSONEncoder().encode(pendingRequests) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadQueue() -> [HybridAgentRequest] {
        let url = queueURL.appendingPathComponent("pending-requests.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HybridAgentRequest].self, from: data) else
        {
            return []
        }
        return decoded
    }

    private func tryCloudRelay(_ request: HybridAgentRequest) async throws -> Bool {
        #if canImport(FirebaseFirestore)
        guard RatioVitaFirebaseBootstrap.isConfigured,
              let productionId = request.productionId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !productionId.isEmpty else
        {
            return false
        }
        guard let db = RatioVitaFirebaseBootstrap.firestore() else {
            throw HybridAgentRelayError.firestoreUnavailable
        }

        let doc = db.collection("productions")
            .document(productionId)
            .collection("hybrid_agent_requests")
            .document(request.id)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let json = try JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: Any] else {
                throw HybridAgentRelayError.invalidRequestPayload
            }
            try await doc.setData(json)
            return true
        }
        #else
        return false
        #endif
    }

    private enum HybridAgentRelayError: LocalizedError {
        case firestoreUnavailable
        case invalidRequestPayload

        var errorDescription: String? {
            switch self {
                case .firestoreUnavailable:
                    "Firestore is configured but its database instance is unavailable."
                case .invalidRequestPayload:
                    "The request could not be represented as a Firestore document."
            }
        }
    }

    private enum HybridAgentResponseError: LocalizedError {
        case documentIdentityMismatch

        var errorDescription: String? {
            "The response document does not match its production or request ID."
        }
    }
}
