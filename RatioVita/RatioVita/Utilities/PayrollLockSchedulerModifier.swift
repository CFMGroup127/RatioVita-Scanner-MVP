import SwiftData
import SwiftUI

/// Runs payroll lock evaluation on launch and when returning to foreground.
struct PayrollLockSchedulerModifier: ViewModifier {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { await tick(reason: "launch") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await tick(reason: "foreground") }
                }
            }
    }

    @MainActor
    private func tick(reason: String) async {
        let ctx = ModelContext(container)
        do {
            let days = try ctx.fetch(FetchDescriptor<CrewTimecardDay>())
            let consult = try ctx.fetch(FetchDescriptor<ConsultationTimecard>())
            let nudges = try PayrollLockScheduler.runTick(
                context: ctx,
                timecardDays: days,
                consultCards: consult
            )
            #if DEBUG
            if !nudges.isEmpty {
                print("PayrollLockScheduler (\(reason)): \(nudges.count) nudge(s)")
            }
            #endif
        } catch {
            #if DEBUG
            print("PayrollLockScheduler: \(error)")
            #endif
        }
    }
}

extension View {
    func payrollLockSchedulerTick(container: ModelContainer) -> some View {
        modifier(PayrollLockSchedulerModifier(container: container))
    }
}
