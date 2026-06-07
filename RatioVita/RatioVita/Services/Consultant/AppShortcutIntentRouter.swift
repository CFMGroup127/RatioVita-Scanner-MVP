import SwiftUI

/// Deep-link style launcher intents → isolated sub-consoles.
@MainActor
enum AppShortcutIntentRouter {
    @ViewBuilder
    static func destination(for intent: LauncherModuleIntent) -> some View {
        switch intent {
            case .driverTransit:
                DriverConsoleView()
            case .instantTimecard:
                InstantTimecardOverlayView()
            case .costumeContinuity:
                CostumeConsoleView()
            case .firstLooks:
                NavigationStack {
                    FirstLooksCaptureView()
                }
            case .tadConsole:
                TADLogisticsDashboardView()
            case .swamperTerminal:
                SwamperTerminalView()
            case .apPayroll:
                NavigationStack {
                    APPayrollPortalView()
                }
            case .administrativeMaster:
                ExpertOnboardingHubView()
        }
    }
}
