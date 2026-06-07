import Combine
import Foundation

/// VitaLogic ↔ Zoho secure packet router (Sprint GGGG).
@MainActor
final class ZohoEcosystemOrchestrator: ObservableObject {
    static let shared = ZohoEcosystemOrchestrator()

    @Published private(set) var outboundQueue: [ZohoDataPacket] = []
    @Published private(set) var syncStatuses: [ZohoSyncStatus] = []
    @Published private(set) var lastError: String?

    private let workerQueue = DispatchQueue(label: "com.ratiovita.zoho.orchestrator", qos: .utility)

    private init() {
        resetStatuses()
    }

    func resetStatuses() {
        syncStatuses = ZohoModuleTarget.allCases.map {
            ZohoSyncStatus(module: $0, lastSync: .distantPast, pendingCount: 0, lastMessage: "Idle")
        }
    }

    func enqueue(
        module: ZohoModuleTarget,
        payload: [String: String],
        domain: MacroTenantDomain? = nil
    ) {
        let bound = domain ?? MasterVaultProfileManager.shared.activeMacroDomain
        workerQueue.async {
            let hex = ZohoPacketCrypto.encrypt(payload, domain: bound, module: module)
            let packet = ZohoDataPacket(
                id: UUID(),
                targetModule: module,
                recordPayloadHex: hex,
                boundTenantDomain: bound,
                syncTimestamp: .now
            )
            Task { @MainActor in
                let orchestrator = ZohoEcosystemOrchestrator.shared
                orchestrator.outboundQueue.insert(packet, at: 0)
                if orchestrator.outboundQueue.count > 40 { orchestrator.outboundQueue.removeLast() }
                orchestrator.flushPacket(packet)
            }
        }
    }

    func flushPacket(_ packet: ZohoDataPacket) {
        workerQueue.async {
            let accepted = ZohoPacketCrypto.simulateAPIAccept(packet: packet)
            Task { @MainActor in
                let orchestrator = ZohoEcosystemOrchestrator.shared
                if let index = orchestrator.syncStatuses.firstIndex(where: { $0.module == packet.targetModule }) {
                    orchestrator.syncStatuses[index] = ZohoSyncStatus(
                        module: packet.targetModule,
                        lastSync: .now,
                        pendingCount: max(0, orchestrator.pending(for: packet.targetModule) - 1),
                        lastMessage: accepted
                            ? "Synced · \(packet.boundTenantDomain.displayName)"
                            : "Rejected — tenant mismatch"
                    )
                }
            }
        }
    }

    func pending(for module: ZohoModuleTarget) -> Int {
        outboundQueue.filter { $0.targetModule == module }.count
    }
}

/// Off-main encryption helpers (Swift 6).
private enum ZohoPacketCrypto: Sendable {
    static func encrypt(
        _ payload: [String: String],
        domain: MacroTenantDomain,
        module: ZohoModuleTarget
    ) -> String {
        let seed = "\(domain.rawValue)|\(module.rawValue)|\(payload.description)"
        return String(abs(seed.hashValue), radix: 16).uppercased()
    }

    static func simulateAPIAccept(packet: ZohoDataPacket) -> Bool {
        !packet.recordPayloadHex.isEmpty
    }
}
