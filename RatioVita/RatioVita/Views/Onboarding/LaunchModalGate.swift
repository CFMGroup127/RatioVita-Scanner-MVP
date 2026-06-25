import SwiftData
import SwiftUI

/// Launch-time modal cases — coordinated with shell navigation through one root sheet.
enum LaunchModal: Identifiable, Equatable {
    case setOSOnboarding
    case sovereignOnboarding
    case consultantLauncher

    var id: Self { self }

    var priority: Int {
        switch self {
        case .setOSOnboarding: 0
        case .sovereignOnboarding: 1
        case .consultantLauncher: 2
        }
    }
}

/// Reconciles launch modal demand without attaching its own `.sheet` modifier.
struct LaunchModalCoordinator: ViewModifier {
    @Binding var activeLaunchModal: LaunchModal?
    @ObservedObject private var setOSCoordinator = SetOSOnboardingCoordinator.shared
    @ObservedObject private var consultantSession = ConsultantSessionManager.shared
    @Query private var profiles: [MasterUserIdentity]

    func body(content: Content) -> some View {
        content
            .onAppear { reconcileLaunchModal() }
            .onChange(of: setOSCoordinator.isComplete) { _, _ in reconcileLaunchModal() }
            .onChange(of: consultantSession.pendingLauncherIntent) { _, _ in reconcileLaunchModal() }
            .onChange(of: profiles.count) { _, _ in reconcileLaunchModal() }
    }

    private func reconcileLaunchModal() {
        var candidates: [LaunchModal] = []
        if !setOSCoordinator.isComplete {
            candidates.append(.setOSOnboarding)
        }
        if profiles.isEmpty, !SovereignFeatureFlags.onboardingCompleted {
            candidates.append(.sovereignOnboarding)
        }
        if consultantSession.pendingLauncherIntent != nil {
            candidates.append(.consultantLauncher)
        }

        let resolved = candidates.min(by: { $0.priority < $1.priority })
        DispatchQueue.main.async {
            activeLaunchModal = resolved
        }
    }
}

extension View {
    func launchModalCoordinator(activeLaunchModal: Binding<LaunchModal?>) -> some View {
        modifier(LaunchModalCoordinator(activeLaunchModal: activeLaunchModal))
    }
}

@MainActor
enum LaunchModalPresenter {
    @ViewBuilder
    static func content(
        for modal: LaunchModal,
        activeLaunchModal: Binding<LaunchModal?>,
        consultantSession: ConsultantSessionManager
    ) -> some View {
        switch modal {
        case .setOSOnboarding:
            OnboardingWizardView {
                activeLaunchModal.wrappedValue = nil
            }
            .interactiveDismissDisabled(true)
        case .sovereignOnboarding:
            OnboardingMasterSetupView {
                activeLaunchModal.wrappedValue = nil
            }
        case .consultantLauncher:
            if let intent = consultantSession.pendingLauncherIntent {
                AppShortcutIntentRouter.destination(for: intent)
                    .onDisappear {
                        _ = consultantSession.consumeLauncherIntent()
                    }
            }
        }
    }
}
