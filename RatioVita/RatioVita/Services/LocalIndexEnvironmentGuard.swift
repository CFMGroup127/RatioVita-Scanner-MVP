import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Guards against LMDB `MDB_MAP_FULL` pressure from Apple's App Intents / Spotlight inline-donation stores
/// and throttles our own background writes when the review queue is very large.
@MainActor
enum LocalIndexEnvironmentGuard {
    private static let mapFullCircuitBreakerKey = "com.ratiovita.index.mapFullCircuitBreaker"
    private static let deferDonationsUntilKey = "com.ratiovita.index.deferDonationsUntil"
    private static let lastPruneKey = "com.ratiovita.index.lastPruneAt"

    /// When true, defer CoreSpotlight-style donations, library snapshots, and finance agent passes.
    static var shouldDeferSystemIndexing: Bool {
        if UserDefaults.standard.bool(forKey: mapFullCircuitBreakerKey) { return true }
        if let until = UserDefaults.standard.object(forKey: deferDonationsUntilKey) as? Date, until > .now {
            return true
        }
        return false
    }

    /// Call once at launch after review-queue count is known.
    static func prepareOnLaunch(reviewQueueCount: Int) {
        configureFirestorePersistenceCapacity()

        if reviewQueueCount >= 1_500 {
            deferSystemDonations(for: 3_600)
            #if DEBUG
            print(
                "[LocalIndexEnvironmentGuard] Large review queue (\(reviewQueueCount)) — deferring system index donations for 1h."
            )
            #endif
        }

        let lastPrune = UserDefaults.standard.object(forKey: lastPruneKey) as? Date
        let shouldPrune = lastPrune == nil || Date().timeIntervalSince(lastPrune!) > 3_600
        if shouldPrune || reviewQueueCount >= 1_000 {
            pruneBloatedSystemIndexCaches(aggressive: reviewQueueCount >= 1_500)
            UserDefaults.standard.set(Date(), forKey: lastPruneKey)
        }
    }

    /// Trip the circuit breaker when console shows `MDB_MAP_FULL` / donation failures.
    static func recordMapFullPressureDetected() {
        UserDefaults.standard.set(true, forKey: mapFullCircuitBreakerKey)
        deferSystemDonations(for: 86_400)
        pruneBloatedSystemIndexCaches(aggressive: true)
        #if DEBUG
        print("[LocalIndexEnvironmentGuard] Map-full pressure recorded — background indexing deferred 24h.")
        #endif
    }

    static func clearMapFullCircuitBreaker() {
        UserDefaults.standard.set(false, forKey: mapFullCircuitBreakerKey)
        UserDefaults.standard.removeObject(forKey: deferDonationsUntilKey)
    }

    static func deferSystemDonations(for seconds: TimeInterval) {
        UserDefaults.standard.set(Date().addingTimeInterval(seconds), forKey: deferDonationsUntilKey)
    }

    // MARK: - Firestore / LevelDB cache headroom

    private static func configureFirestorePersistenceCapacity() {
        #if canImport(FirebaseFirestore)
        guard RatioVitaFirebaseBootstrap.isConfigured else { return }
        let settings = FirestoreSettings()
        settings.cacheSizeBytes = 400 * 1024 * 1024
        Firestore.firestore().settings = settings
        #if DEBUG
        print("[LocalIndexEnvironmentGuard] Firestore cache size set to 400 MB.")
        #endif
        #endif
    }

    // MARK: - App Intents / Spotlight LMDB cache prune

    /// Apple's inline donation indexer (CSInlineDonation) uses LMDB under the app container.
    /// We cannot call `mdb_env_set_mapsize` on that store — prune bloated caches instead.
    private static func pruneBloatedSystemIndexCaches(aggressive: Bool) {
        let fm = FileManager.default
        var roots: [URL] = []
        if let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            roots.append(lib)
        }
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            roots.append(support)
        }
        if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ratiovita.shared") {
            roots.append(container)
        }

        let relativeCandidates = [
            "com.apple.AppIntents",
            "AppIntents",
            "Spotlight",
            "CSIndex",
            "Donations",
        ]

        let sizeThreshold: UInt64 = aggressive ? 8 * 1024 * 1024 : 64 * 1024 * 1024

        for root in roots {
            for name in relativeCandidates {
                let url = root.appendingPathComponent(name, isDirectory: true)
                guard fm.fileExists(atPath: url.path) else { continue }
                let bytes = directoryByteSize(at: url) ?? 0
                if bytes >= sizeThreshold {
                    removeIndexCache(at: url, bytes: bytes)
                }
            }
            if aggressive {
                pruneOrphanedLMDBPairs(under: root, maxPairBytes: sizeThreshold)
            }
        }
    }

    private static func pruneOrphanedLMDBPairs(under root: URL, maxPairBytes: UInt64) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var dataFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "data.mdb" else { continue }
            dataFiles.append(fileURL)
        }

        for dataURL in dataFiles {
            let folder = dataURL.deletingLastPathComponent()
            let bytes = directoryByteSize(at: folder) ?? 0
            guard bytes >= maxPairBytes else { continue }
            removeIndexCache(at: folder, bytes: bytes)
        }
    }

    private static func removeIndexCache(at url: URL, bytes: UInt64) {
        do {
            try FileManager.default.removeItem(at: url)
            #if DEBUG
            print("[LocalIndexEnvironmentGuard] Pruned index cache \(url.path) (\(bytes) bytes).")
            #endif
        } catch {
            #if DEBUG
            print("[LocalIndexEnvironmentGuard] Could not prune \(url.path): \(error.localizedDescription)")
            #endif
        }
    }

    private static func directoryByteSize(at url: URL) -> UInt64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize
            else { continue }
            total += UInt64(size)
        }
        return total
    }
}
