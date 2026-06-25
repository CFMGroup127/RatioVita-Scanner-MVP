import SwiftData
import SwiftUI

/// Presents atomic launcher sheet when consultant program queues an intent.
struct ConsultantProgramGate: ViewModifier {
    @ObservedObject private var session = ConsultantSessionManager.shared
    @State private var showLauncher = false

    func body(content: Content) -> some View {
        content
            .onAppear { checkLauncher() }
            .onChange(of: session.pendingLauncherIntent) { _, _ in checkLauncher() }
            .sheet(isPresented: $showLauncher) {
                if let intent = session.pendingLauncherIntent {
                    AppShortcutIntentRouter.destination(for: intent)
                        .onDisappear {
                            _ = session.consumeLauncherIntent()
                            showLauncher = false
                        }
                }
            }
    }

    private func checkLauncher() {
        showLauncher = session.pendingLauncherIntent != nil
    }
}

extension View {
    /// Deprecated — launch modals are coordinated by `launchModalGate()` on the app root.
    func consultantProgramGate() -> some View { self }
}
