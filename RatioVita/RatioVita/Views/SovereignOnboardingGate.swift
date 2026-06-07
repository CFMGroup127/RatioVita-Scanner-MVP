import SwiftData
import SwiftUI

/// Presents sovereign onboarding until a profile exists or the user marks setup complete.
struct SovereignOnboardingGate: ViewModifier {
    @Query private var profiles: [MasterUserIdentity]
    @State private var showOnboarding = false

    func body(content: Content) -> some View {
        content
            .onAppear { evaluateGate() }
            .sheet(isPresented: $showOnboarding) {
                OnboardingMasterSetupView {
                    showOnboarding = false
                }
            }
    }

    private func evaluateGate() {
        let needsProfile = profiles.isEmpty && !SovereignFeatureFlags.onboardingCompleted
        showOnboarding = needsProfile
    }
}

extension View {
    func sovereignOnboardingGate() -> some View {
        modifier(SovereignOnboardingGate())
    }
}
