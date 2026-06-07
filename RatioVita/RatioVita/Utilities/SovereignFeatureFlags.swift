import Foundation

/// Module toggles for the Apple-style settings cockpit (sidebar visibility + feature gates).
enum SovereignFeatureFlags {
    static let manuscriptVaultKey = "com.ratiovita.feature.manuscriptVault"
    static let capExProcurementKey = "com.ratiovita.feature.capExProcurement"
    static let craftLogisticsMeshKey = "com.ratiovita.feature.craftLogisticsMesh"
    static let bioInsulationTrackerKey = "com.ratiovita.feature.bioInsulationTracker"
    static let craftMicroTransactionsKey = "com.ratiovita.feature.craftMicroTransactions"
    static let transportRunnerRoutingKey = "com.ratiovita.feature.transportRunnerRouting"
    static let venueGroupCheckoutKey = "com.ratiovita.feature.venueGroupCheckout"
    static let shakeToFeedbackKey = "com.ratiovita.feature.shakeToFeedback"
    static let onboardingCompletedKey = "com.ratiovita.sovereign.onboardingCompleted"

    static var manuscriptVaultEnabled: Bool {
        get { UserDefaults.standard.object(forKey: manuscriptVaultKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: manuscriptVaultKey) }
    }

    static var capExProcurementEnabled: Bool {
        get { UserDefaults.standard.object(forKey: capExProcurementKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: capExProcurementKey) }
    }

    static var craftLogisticsMeshEnabled: Bool {
        get { UserDefaults.standard.object(forKey: craftLogisticsMeshKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: craftLogisticsMeshKey) }
    }

    static var bioInsulationTrackerEnabled: Bool {
        get { UserDefaults.standard.object(forKey: bioInsulationTrackerKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: bioInsulationTrackerKey) }
    }

    static var craftMicroTransactionsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: craftMicroTransactionsKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: craftMicroTransactionsKey) }
    }

    static var transportRunnerRoutingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: transportRunnerRoutingKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: transportRunnerRoutingKey) }
    }

    static var venueGroupCheckoutEnabled: Bool {
        get { UserDefaults.standard.object(forKey: venueGroupCheckoutKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: venueGroupCheckoutKey) }
    }

    /// Tester feedback channel — shake (iOS) or ⌘⇧F (Mac). Disable after department certification.
    static var shakeToFeedbackEnabled: Bool {
        get { UserDefaults.standard.object(forKey: shakeToFeedbackKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: shakeToFeedbackKey) }
    }

    static var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
    }
}
