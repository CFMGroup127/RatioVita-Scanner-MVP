//
//  RatioVitaApp.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

private let lastDailyLedgerRunKey = "com.ratiovita.lastDailyLedgerRunDate"

/// Creates the SwiftData stack, with a one-time store reset if an incompatible on-disk model blocks launch
/// (e.g. after additive schema changes on a simulator/device build).
private enum SwiftDataAppContainer {
    static func make() -> ModelContainer {
        let schema = LibrarySwiftDataSchema.makeSchema()
        #if RATIOVITA_ICLOUD_SYNC
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic
        #else
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
        #endif
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let allowReset = UserDefaults.standard.bool(forKey: "com.ratiovita.allowDestructiveStoreReset")
            #if DEBUG
            print("RatioVita: ModelContainer failed (\(error)) at \(configuration.url). allowReset=\(allowReset)")
            #endif
            guard allowReset else {
                fatalError(
                    """
                    RatioVita could not open the library database (schema may have changed). \
                    Your data is still on disk. Enable destructive reset in Settings → Developer, or restore from Sovereign. \
                    Error: \(error)
                    """
                )
            }
            ReceiptWorkspaceBatchGuard.backupAndRemoveStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer after backup: \(error)")
            }
        }
    }
}

@main
struct RatioVitaApp: App {
    @State private var libraryNavigationCoordinator = LibraryNavigationCoordinator()
    var sharedModelContainer: ModelContainer = SwiftDataAppContainer.make()

    init() {
        RatioVitaFirebaseBootstrap.configureIfNeeded()
        #if DEBUG
        #if canImport(UIKit)
        // Quiets “Unable to simultaneously satisfy constraints” spam from UIKit-backed text inputs (does not affect
        // layout resolution). FigCapture / AVFoundation device logs are OS-level; reduce those via the Run scheme’s
        // environment (e.g. OS_ACTIVITY_MODE) if needed — there is no supported in-app filter.
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        #endif
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ratioVitaTheme()
                .environment(libraryNavigationCoordinator)
                .environmentObject(SovereignContextManager.shared)
                .logisticsLiveSync()
                .sovereignOnboardingGate()
                .setOSOnboardingGate()
                .consultantProgramGate()
                .onOpenURL { url in
                    _ = NativeLauncherShortcutManager.handleIncomingURL(url)
                }
                .task { @MainActor in
                    let ctx = ModelContext(sharedModelContainer)
                    if let recovery = ReceiptWorkspaceBatchGuard.consumePendingRecoveryAlert() {
                        UserMessageCenter.shared.present(
                            title: "Library database upgraded",
                            message: recovery
                        )
                    } else if let regression = LibraryPersistenceMonitor.regressionHint(context: ctx) {
                        UserMessageCenter.shared.present(
                            title: "Library count changed",
                            message: regression
                        )
                    }
                    LibraryPersistenceMonitor.recordSnapshot(context: ctx, reason: "launch")
                    _ = try? NewHorizonsSampleDataGenerator.seedBurlingtonEstateIfNeeded(modelContext: ctx)
                    RatioVitaBackupManager.runScheduledAutoArchiveIfNeeded(modelContext: ctx)
                    #if os(iOS)
                    await PhotoLibraryLaunchAutoScan.runIfEnabled(modelContext: ctx)
                    #endif
                    await VaultLaunchSyncPrompt.checkAndNotify(modelContext: ctx)
                    await RemoteConfigSynchronizer.shared.syncIfNeeded(trigger: "launch")
                }
                .modifier(DailyLedger5PMTrigger(container: sharedModelContainer))
                .modifier(FinanceAgentsPeriodicTrigger(container: sharedModelContainer))
                .modifier(GeminiLaunchAndVaultBankInboxModifier(container: sharedModelContainer))
                .payrollLockSchedulerTick(container: sharedModelContainer)
                .temporalAuthExpirationTick(container: sharedModelContainer)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.automatic)
        .commands {
            CommandMenu("Tester") {
                Button("Send feedback…") {
                    LiveFeedbackManager.shared.presentFeedback(context: "Menu · Tester")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        #endif
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - 5 PM Daily Ledger Trigger (Monday Ignition)

/// Fires once per day at 17:00 (5:00 PM): runs DailyLedgerService to generate the day's ledger.
struct DailyLedger5PMTrigger: ViewModifier {
    let container: ModelContainer

    func body(content: Content) -> some View {
        content
            .onAppear {
                start5PMCheck()
            }
    }

    private func start5PMCheck() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await runIf5PM()
            }
        }
        // Run once immediately in case we're already past 5 PM
        Task { @MainActor in
            await runIf5PM()
        }
    }

    @MainActor
    private func runIf5PM() async {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        guard hour == 17 else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        let lastRun = UserDefaults.standard.string(forKey: lastDailyLedgerRunKey)
        guard lastRun != today else { return }

        let context = ModelContext(container)
        defer {
            // One attempt per calendar day (success or failure) so we don't retry every minute at 5 PM.
            UserDefaults.standard.set(today, forKey: lastDailyLedgerRunKey)
        }
        do {
            _ = try await DailyLedgerService.shared.generateDailyLedger(for: now, modelContext: context)
        } catch {
            UserMessageCenter.shared.present(
                title: "Daily ledger",
                message: error.ratioVitaUserDescription
            )
        }
    }
}

// MARK: - Gemini connectivity + Vault bank inbox (launch)

/// Verifies the Gemini API key once per window appearance and imports any files waiting in
/// `Vault/BankStatements/Inbox`.
struct GeminiLaunchAndVaultBankInboxModifier: ViewModifier {
    let container: ModelContainer
    @State private var ranConnectivity = false

    func body(content: Content) -> some View {
        content
            .task { @MainActor in
                guard !ranConnectivity else { return }
                ranConnectivity = true
                GeminiAPIKeyKeychain.migrateFromUserDefaultsIfNeeded()
                _ = GeminiAPIKeyResolver.resolveModelId()
                await GeminiConnectionStatusStore.shared.refreshFromCurrentSettings()
                let ctx = ModelContext(container)
                let inbox = await BankStatementImportCoordinator.processVaultBankStatementInbox(
                    modelContext: ctx,
                    geminiProgress: nil
                )
                if inbox.rowsInserted > 0 {
                    UserMessageCenter.shared.present(
                        title: "Bank import",
                        message: "Imported \(inbox.rowsInserted) row\(inbox.rowsInserted == 1 ? "" : "s") from \(inbox.filesProcessed) Vault file\(inbox.filesProcessed == 1 ? "" : "s")."
                    )
                } else if !inbox.failures.isEmpty {
                    let head = inbox.failures.prefix(2).joined(separator: "\n")
                    let more = inbox.failures.count > 2 ? "\n… and \(inbox.failures.count - 2) more." : ""
                    UserMessageCenter.shared.present(
                        title: "Bank import (Vault inbox)",
                        message: head + more
                    )
                }

                let zoho = await ZohoVaultInvoiceCoordinator.processVaultZohoInbox(modelContext: ctx)
                if zoho.receiptsCreated > 0 || zoho.contactsInserted > 0 || zoho.contactsMerged > 0 {
                    var parts: [String] = []
                    if zoho.receiptsCreated > 0 {
                        parts.append(
                            "Created \(zoho.receiptsCreated) invoice receipt(s) from \(zoho.filesProcessed) PDF(s)."
                        )
                    }
                    if zoho.contactsInserted > 0 || zoho.contactsMerged > 0 {
                        parts.append(
                            "Contacts: \(zoho.contactsInserted) new, \(zoho.contactsMerged) merged from \(zoho.contactFilesProcessed) CSV file(s)."
                        )
                    }
                    UserMessageCenter.shared.present(
                        title: "Zoho inbox",
                        message: parts.joined(separator: " ")
                    )
                } else if !zoho.failures.isEmpty {
                    let head = zoho.failures.prefix(2).joined(separator: "\n")
                    let more = zoho.failures.count > 2 ? "\n… and \(zoho.failures.count - 2) more." : ""
                    UserMessageCenter.shared.present(
                        title: "Zoho inbox",
                        message: head + more
                    )
                }
            }
    }
}

// MARK: - Finance agents (Tax + bank reconciliation) — foreground periodic pass

private let financeAgentsPeriodicEnabledKey = "financeAgentsPeriodicEnabled"
private let lastFinanceAgentsRunKey = "com.ratiovita.lastFinanceAgentsRun"

/// While the app is open, periodically runs lightweight Tax / GL heuristics and bank-transaction matching.
struct FinanceAgentsPeriodicTrigger: ViewModifier {
    let container: ModelContainer

    func body(content: Content) -> some View {
        content
            .onAppear {
                startFinanceAgentsTimer()
            }
    }

    private func startFinanceAgentsTimer() {
        Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { _ in
            Task { @MainActor in
                await runFinanceAgentsIfDue()
            }
        }
        Task { @MainActor in
            await runFinanceAgentsIfDue()
        }
    }

    @MainActor
    private func runFinanceAgentsIfDue() async {
        let enabled = UserDefaults.standard.object(forKey: financeAgentsPeriodicEnabledKey) as? Bool ?? true
        guard enabled else { return }

        let now = Date()
        if let last = UserDefaults.standard.object(forKey: lastFinanceAgentsRunKey) as? Date,
           now.timeIntervalSince(last) < 90
        {
            return
        }
        UserDefaults.standard.set(now, forKey: lastFinanceAgentsRunKey)

        let context = ModelContext(container)
        do {
            try ReceiptFinanceAgentsService.runAll(modelContext: context)
        } catch {
            #if DEBUG
            print("RatioVita: Finance agents pass failed: \(error)")
            #endif
        }
    }
}
