import Combine
import Foundation

/// File-backed optimistic cache — UI reads here first, never blocks on Firestore ACK.
@MainActor
final class LogisticsLocalCacheStore: ObservableObject {
    static let shared = LogisticsLocalCacheStore()

    @Published private(set) var productionDayState: ProductionDayStateSnapshot?
    @Published private(set) var lastUpdatedLocally: Date?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func cacheURL(for productionId: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("RatioVita/LogisticsCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeId = productionId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
        return folder.appendingPathComponent("\(safeId)-production-day-state.json")
    }

    func loadCachedState(productionId: String) -> ProductionDayStateSnapshot? {
        let url = cacheURL(for: productionId)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(ProductionDayStateSnapshot.self, from: data) else {
            return nil
        }
        productionDayState = snapshot
        lastUpdatedLocally = snapshot.lastUpdated
        return snapshot
    }

    func saveState(_ snapshot: ProductionDayStateSnapshot) {
        productionDayState = snapshot
        lastUpdatedLocally = .now
        let url = cacheURL(for: snapshot.productionId)
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func applyRemoteState(_ snapshot: ProductionDayStateSnapshot) {
        saveState(snapshot)
    }
}
