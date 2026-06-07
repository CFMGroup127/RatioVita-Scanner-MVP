import AppIntents

// MARK: - Per-department App Shortcuts (Home Screen / Spotlight)

struct OpenDriverConsoleIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · Driver"
    static var description = IntentDescription("Open the hands-free IA 873 driver console.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.driverTransit)
        }
        return .result()
    }
}

struct OpenTimecardOverlayIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · Timecard"
    static var description = IntentDescription("Instant in/out time log overlay.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.instantTimecard)
        }
        return .result()
    }
}

struct OpenCostumeConsoleIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · Costume"
    static var description = IntentDescription("Costume trailer continuity console.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.costumeContinuity)
        }
        return .result()
    }
}

struct OpenAPPayrollIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · AP Payroll"
    static var description = IntentDescription("Accounts payable and payroll vault.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.apPayroll)
        }
        return .result()
    }
}

struct OpenTADConsoleIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · TAD"
    static var description = IntentDescription("Trailer Assistant Director logistics grid.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.tadConsole)
        }
        return .result()
    }
}

struct OpenFirstLooksIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · First Looks"
    static var description = IntentDescription("Costume truck first-look checkpoint.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.firstLooks)
        }
        return .result()
    }
}

struct OpenSwamperTerminalIntent: AppIntent {
    static var title: LocalizedStringResource = "RV · Swamper"
    static var description = IntentDescription("Trailer sanitization and lockup terminal.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NativeLauncherShortcutManager.launch(.swamperTerminal)
        }
        return .result()
    }
}

struct RatioVitaShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDriverConsoleIntent(),
            phrases: [
                "Open Driver in \(.applicationName)",
                "RV Driver in \(.applicationName)",
            ],
            shortTitle: "RV · Driver",
            systemImageName: "steeringwheel"
        )
        AppShortcut(
            intent: OpenTimecardOverlayIntent(),
            phrases: [
                "Log timecard in \(.applicationName)",
                "RV Timecard in \(.applicationName)",
            ],
            shortTitle: "RV · Timecard",
            systemImageName: "stopwatch"
        )
        AppShortcut(
            intent: OpenCostumeConsoleIntent(),
            phrases: [
                "Open Costume in \(.applicationName)",
                "RV Costume in \(.applicationName)",
            ],
            shortTitle: "RV · Costume",
            systemImageName: "hanger"
        )
        AppShortcut(
            intent: OpenAPPayrollIntent(),
            phrases: [
                "Open AP Payroll in \(.applicationName)",
                "RV Payroll in \(.applicationName)",
            ],
            shortTitle: "RV · AP Payroll",
            systemImageName: "lock.shield"
        )
        AppShortcut(
            intent: OpenTADConsoleIntent(),
            phrases: [
                "Open TAD in \(.applicationName)",
                "RV TAD in \(.applicationName)",
            ],
            shortTitle: "RV · TAD",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: OpenFirstLooksIntent(),
            phrases: [
                "First Looks in \(.applicationName)",
                "RV First Looks in \(.applicationName)",
            ],
            shortTitle: "RV · First Looks",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: OpenSwamperTerminalIntent(),
            phrases: [
                "Open Swamper in \(.applicationName)",
                "RV Swamper in \(.applicationName)",
            ],
            shortTitle: "RV · Swamper",
            systemImageName: "sparkles"
        )
    }
}
