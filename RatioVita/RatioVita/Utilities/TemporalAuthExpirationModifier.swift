import SwiftData
import SwiftUI

/// Prunes expired temporal role grants on launch and foreground (Sprint SSS).
struct TemporalAuthExpirationModifier: ViewModifier {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { await prune(reason: "launch") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await prune(reason: "foreground") }
                }
            }
    }

    @MainActor
    private func prune(reason: String) async {
        let ctx = ModelContext(container)
        TemporalAuthorizationService.pruneExpired(context: ctx)
        #if DEBUG
        print("TemporalAuthExpiration (\(reason)): prune complete")
        #endif
    }
}

extension View {
    func temporalAuthExpirationTick(container: ModelContainer) -> some View {
        modifier(TemporalAuthExpirationModifier(container: container))
    }
}
