import Foundation

/// Short-circuits App Intents / CoreSpotlight inline donations (`CSInlineDonation`) that can deadlock
/// the main thread when Apple's LMDB donation store is full.
enum SystemIndexingDonationGuard {
    /// Shared with `@AppStorage("disableSystemIndexing")` in SwiftUI settings surfaces.
    static let disableSystemIndexingKey = "disableSystemIndexing"

    /// Run scheme env `RV_DISABLE_SYSTEM_INDEXING=1` to force suppression (Debug runs, Profile, etc.).
    private static let forceSuppressFromEnvironment: Bool = {
        let raw = ProcessInfo.processInfo.environment["RV_DISABLE_SYSTEM_INDEXING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw == "1" || raw?.lowercased() == "true" || raw?.lowercased() == "yes"
    }()

    /// Executes before `@main` when the delegate static initializer runs (earliest app hook we control).
    static let loadTimeActivation: Void = {
        applyDevelopmentBypassIfNeeded()
    }()

    /// When true, skip shortcut donation registration and other background indexing passes.
    static var isSuppressed: Bool {
        if forceSuppressFromEnvironment { return true }
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: disableSystemIndexingKey)
            || LocalIndexEnvironmentGuard.shouldDeferSystemIndexing
        #endif
    }

    static func setDisableSystemIndexing(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disableSystemIndexingKey)
    }

    /// Call as early as possible — before SwiftUI presents its first view.
    static func applyDevelopmentBypassIfNeeded() {
        #if DEBUG
        setDisableSystemIndexing(true)
        emitBypassLog()
        #else
        if forceSuppressFromEnvironment {
            setDisableSystemIndexing(true)
            emitBypassLog()
        }
        #endif
    }

    /// Wraps any explicit donation / indexing registration hook.
    static func performIfAllowed(_ action: () -> Void) {
        guard !isSuppressed else {
            #if DEBUG
            emitBypassLog()
            #endif
            return
        }
        action()
    }

    private static func emitBypassLog() {
        print(
            "[SECURITY BYPASS] Skipping system indexing donation in development to prevent MDB_MAP_FULL daemon deadlocks."
        )
    }
}
