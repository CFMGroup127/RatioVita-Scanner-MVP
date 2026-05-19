import Combine
import Foundation
import SwiftUI

/// Shared Gemini reachability for Settings and app launch (`GeminiReceiptExtractionService.verifyAPIKeyConnectivity`).
@MainActor
final class GeminiConnectionStatusStore: ObservableObject {
    static let shared = GeminiConnectionStatusStore()

    enum State: Equatable {
        case unknown
        case idleNoKey
        case disabled
        case checking
        case connected
        case failed(String)
    }

    @Published private(set) var state: State = .unknown
    @Published private(set) var lastChecked: Date?

    private init() {}

    /// Reads key + toggles from `GeminiAPIKeyResolver` / `UserDefaults`, then hits the Gemini `models.list` endpoint.
    func refreshFromCurrentSettings() async {
        _ = GeminiAPIKeyResolver.resolveModelId()
        let enabled = GeminiAPIKeyResolver.isGeminiExtractionEnabled()
        let key = GeminiAPIKeyResolver.resolveAPIKeyTrimmed()

        guard enabled else {
            state = .disabled
            lastChecked = .now
            return
        }
        guard !key.isEmpty else {
            state = .idleNoKey
            lastChecked = .now
            return
        }

        state = .checking
        do {
            try await GeminiReceiptExtractionService.verifyAPIKeyConnectivity(apiKey: key)
            state = .connected
        } catch {
            state = .failed(error.localizedDescription)
        }
        lastChecked = .now
    }
}
