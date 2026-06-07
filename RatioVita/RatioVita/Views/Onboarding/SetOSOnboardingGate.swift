import SwiftUI

/// Blocks the main shell until SetOS white-glove onboarding completes (Sprint JJJJ).
struct SetOSOnboardingGate: ViewModifier {
    @ObservedObject private var coordinator = SetOSOnboardingCoordinator.shared
    @State private var showWizard = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                scheduleWizardPresentation()
            }
            .onChange(of: coordinator.isComplete) { _, _ in
                scheduleWizardPresentation()
            }
            .modifier(OnboardingWizardPresentationModifier(isPresented: $showWizard))
    }

    private func scheduleWizardPresentation() {
        Task { @MainActor in
            showWizard = !coordinator.isComplete
        }
    }
}

/// iOS uses full-screen cover; macOS uses sheet (fullScreenCover is unavailable there).
private struct OnboardingWizardPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .fullScreenCover(isPresented: $isPresented) {
                OnboardingWizardView {
                    isPresented = false
                }
            }
        #else
        content
            .sheet(isPresented: $isPresented) {
                OnboardingWizardView {
                    isPresented = false
                }
                #if os(macOS)
                .frame(minWidth: 560, minHeight: 640)
                #endif
            }
        #endif
    }
}

extension View {
    func setOSOnboardingGate() -> some View {
        modifier(SetOSOnboardingGate())
    }
}
