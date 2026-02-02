//
//  RatioVitaApp.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

private let lastDailyLedgerRunKey = "com.ratiovita.lastDailyLedgerRunDate"

@main
struct RatioVitaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Receipt.self,
            ReceiptImage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ratioVitaTheme()
                .modifier(DailyLedger5PMTrigger(container: sharedModelContainer))
        }
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
        do {
            _ = try await DailyLedgerService.shared.generateDailyLedger(for: now, modelContext: context)
            UserDefaults.standard.set(today, forKey: lastDailyLedgerRunKey)
        } catch {
            // Log but don't block; will retry next minute or next day
        }
    }
}
