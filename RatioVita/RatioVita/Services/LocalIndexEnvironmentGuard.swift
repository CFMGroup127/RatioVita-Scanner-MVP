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

    /// Mirrors `@AppStorage("disableSystemIndexing")`.
    static let disableSystemIndexingKey = SystemIndexingDonationGuard.disableSystemIndexingKey

    static var isSystemIndexingDisabled: Bool {
        UserDefaults.standard.bool(forKey: disableSystemIndexingKey)
    }

    static func setDisableSystemIndexing(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disableSystemIndexingKey)
    }

    /// When true, defer CoreSpotlight-style donations, library snapshots, and finance agent passes.
    static var shouldDeferSystemIndexing: Bool {
        #if DEBUG
        return true
        #else
        if isSystemIndexingDisabled { return true }
        if UserDefaults.standard.bool(forKey: mapFullCircuitBreakerKey) { return true }
        if let until = UserDefaults.standard.object(forKey: deferDonationsUntilKey) as? Date, until > .now {
            return true
        }
        return false
        #endif
    }

    /// Call once at launch after review-queue count is known.
    static func prepareOnLaunch(reviewQueueCount: Int) {
        SystemIndexingDonationGuard.applyDevelopmentBypassIfNeeded()
        configureFirestorePersistenceCapacity()

        if reviewQueueCount >= 1_500 {
            setDisableSystemIndexing(true)
            deferSystemDonations(for: 3_600)
            #if DEBUG
            print(
                "[LocalIndexEnvironmentGuard] Large review queue (\(reviewQueueCount)) — disableSystemIndexing=true."
            )
            #endif
        }
    }

    /// Trip the circuit breaker when console shows `MDB_MAP_FULL` / donation failures.
    static func recordMapFullPressureDetected() {
        UserDefaults.standard.set(true, forKey: mapFullCircuitBreakerKey)
        setDisableSystemIndexing(true)
        deferSystemDonations(for: 86_400)
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
        RatioVitaFirebaseBootstrap.applyFirestoreCacheSettings()
        #if DEBUG
        print("[LocalIndexEnvironmentGuard] Firestore persistent cache set to 400 MB.")
        #endif
        #endif
    }
}
