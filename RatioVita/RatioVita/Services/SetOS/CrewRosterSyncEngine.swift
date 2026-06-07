import Combine
import Foundation

/// Gate telemetry + Vita Voice logs → Zoho People/Shifts (Sprint GGGG).
@MainActor
final class CrewRosterSyncEngine: ObservableObject {
    static let shared = CrewRosterSyncEngine()

    @Published private(set) var pendingSignOff: [AutoTimecardDraft] = []

    private let workerQueue = DispatchQueue(label: "com.ratiovita.zoho.roster", qos: .utility)

    private init() {}

    func compileWrapBatch(
        department: IndustryDepartmentScope,
        crewTokens: [String],
        gateCheckIns: Int,
        voiceLogEntries: Int
    ) {
        let departmentLabel = department.displayName
        workerQueue.async {
            let drafts = crewTokens.map { token in
                AutoTimecardDraft(
                    id: UUID(),
                    crewToken: token,
                    departmentLabel: departmentLabel,
                    hoursComputed: CrewRosterHoursCalculator.hours(
                        gateCheckIns: gateCheckIns,
                        voiceLogs: voiceLogEntries
                    ),
                    gateCheckIns: gateCheckIns,
                    voiceLogEntries: voiceLogEntries,
                    readyForSignOff: true
                )
            }
            Task { @MainActor in
                let engine = CrewRosterSyncEngine.shared
                engine.pendingSignOff = drafts
                for draft in drafts {
                    ZohoEcosystemOrchestrator.shared.enqueue(
                        module: .peopleShifts,
                        payload: [
                            "crew": draft.crewToken,
                            "hours": String(format: "%.2f", draft.hoursComputed),
                            "department": draft.departmentLabel,
                            "gates": "\(draft.gateCheckIns)",
                            "voice_logs": "\(draft.voiceLogEntries)",
                        ]
                    )
                }
            }
        }
    }

    func confirmDraft(id: UUID) {
        guard let index = pendingSignOff.firstIndex(where: { $0.id == id }) else { return }
        let draft = pendingSignOff[index]
        ZohoEcosystemOrchestrator.shared.enqueue(
            module: .peopleShifts,
            payload: [
                "crew": draft.crewToken,
                "confirmed": "true",
                "hours": String(format: "%.2f", draft.hoursComputed),
            ]
        )
        pendingSignOff.remove(at: index)
    }
}

private enum CrewRosterHoursCalculator: Sendable {
    static func hours(gateCheckIns: Int, voiceLogs: Int) -> Double {
        let base = 10.5
        let gateBonus = Double(min(gateCheckIns, 4)) * 0.15
        let voiceBonus = Double(min(voiceLogs, 6)) * 0.05
        return base + gateBonus + voiceBonus
    }
}
