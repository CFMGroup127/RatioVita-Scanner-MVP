import Foundation

/// Short-circuits App Intents / CoreSpotlight inline donations (`CSInlineDonation`) that can deadlock
/// the main thread when Apple's LMDB donation store is full.
enum SystemIndexingDonationGuard {
    /// Shared with `@AppStorage("disableSystemIndexing")` in SwiftUI settings surfaces.
    static let disableSystemIndexingKey = "disableSystemIndexing"

    /// When true, skip shortcut donation registration and other background indexing passes.
    static var isSuppressed: Bool {
        #if DEBUG
        return true
        #else
        return LocalIndexEnvironmentGuard.shouldDeferSystemIndexing
        #endif
    }

    /// Call as early as possible — before SwiftUI presents its first view.
    static func applyDevelopmentBypassIfNeeded() {
        #if DEBUG
        LocalIndexEnvironmentGuard.setDisableSystemIndexing(true)
        print(
            "[SECURITY BYPASS] Skipping system indexing donation in development to prevent MDB_MAP_FULL daemon deadlocks."
        )
        #endif
    }

    /// Wraps any explicit donation / indexing registration hook.
    static func performIfAllowed(_ action: () -> Void) {
        #if DEBUG
        print(
            "[SECURITY BYPASS] Skipping system indexing donation in development to prevent MDB_MAP_FULL daemon deadlocks."
        )
        #else
        guard !isSuppressed else { return }
        action()
        #endif
    }
}
