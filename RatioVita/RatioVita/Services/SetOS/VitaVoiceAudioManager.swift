import AVFoundation
import Combine
import Foundation

/// Hands-free verbal mesh — AVAudioEngine + tenant/rank routing (Sprint FFFF).
@MainActor
final class VitaVoiceAudioManager: ObservableObject {
    static let shared = VitaVoiceAudioManager()

    @Published private(set) var subscribedChannels: [ActiveAudioChannel] = []
    @Published private(set) var activeSpatialBridge: SpatialVoiceBridge?
    @Published private(set) var activeSpeakerLabel: String?
    @Published private(set) var recentPackets: [VoicePacket] = []
    @Published private(set) var isPTTActive = false
    @Published private(set) var isEngineReady = false
    @Published private(set) var sessionStatus: String = "Idle"

    private let workerQueue = DispatchQueue(label: "com.ratiovita.vita.voice.worker", qos: .userInitiated)
    private let engineBox = VoiceAudioEngineBox()

    private init() {}

    func refreshSubscriptions() {
        let vault = MasterVaultProfileManager.shared
        let session = ConsultantSessionManager.shared
        let rank = vault.activePersona?.rankTier
            ?? DepartmentScopeController.structuralRank(
                hat: session.activeOperationalHat,
                department: nil,
                consultantTier: nil
            )
        let domain = vault.activeMacroDomain

        tearDownSpatialBridge()
        subscribedChannels = AudioChannelMatrix.subscribedChannels(domain: domain, rank: rank)
        sessionStatus = "Bound to \(domain.displayName) · \(rank.displayName) · \(subscribedChannels.count) channel(s)"
        configureAudioSessionIfNeeded()
    }

    func configureAudioSessionIfNeeded() {
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { _ in }
        workerQueue.async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
                try session.setActive(true)
                Task { @MainActor in
                    VitaVoiceAudioManager.shared.isEngineReady = true
                }
            } catch {
                Task { @MainActor in
                    let manager = VitaVoiceAudioManager.shared
                    manager.sessionStatus = "Audio session: \(error.localizedDescription)"
                    manager.isEngineReady = false
                }
            }
        }
        #else
        isEngineReady = true
        sessionStatus = "macOS · simulated voice routing (no AVAudioSession)"
        #endif
    }

    func startPushToTalk() {
        isPTTActive = true
        sessionStatus = "PTT open · \(subscribedChannels.first?.channelName ?? "no channel")"
        #if os(iOS)
        let box = engineBox
        workerQueue.async {
            do {
                try VoiceAudioEngineBox.startRecording(in: box)
                Task { @MainActor in
                    VitaVoiceAudioManager.shared.sessionStatus =
                        "PTT active · \(VitaVoiceAudioManager.shared.subscribedChannels.first?.channelName ?? "")"
                }
            } catch {
                Task { @MainActor in
                    let manager = VitaVoiceAudioManager.shared
                    manager.sessionStatus = "Engine start failed: \(error.localizedDescription)"
                    manager.isPTTActive = false
                }
            }
        }
        #endif
    }

    func stopPushToTalk() {
        isPTTActive = false
        #if os(iOS)
        let box = engineBox
        workerQueue.async {
            VoiceAudioEngineBox.stopRecording(in: box)
        }
        #endif
    }

    func broadcast(
        message: String,
        priority: AudioStreamPriority,
        senderLabel: String? = nil
    ) {
        let vault = MasterVaultProfileManager.shared
        let session = ConsultantSessionManager.shared
        let domain = vault.activeMacroDomain
        let label = senderLabel ?? vault.activePersona?.positionTitle ?? session.activeOperationalHat.displayName

        guard let channel = resolveChannel(priority: priority, domain: domain) else {
            sessionStatus = "No channel for priority \(priority.displayName)"
            return
        }

        let minimumTier: StructuralRankTier = switch priority {
            case .administrativeWhisper:
                .departmentHead
            case .emergencyAlert, .tacticalDepartment, .standardChat:
                .fieldCrew
        }

        let personas = vault.personas
        workerQueue.async {
            let encoded = VitaVoicePacketEncoder.encode(message: message, priority: priority)
            let packet = VoicePacket(
                id: UUID(),
                senderLabel: label,
                message: message,
                priority: priority,
                domain: domain,
                minimumTier: minimumTier,
                channelID: channel.id,
                encodedAt: .now
            )
            let recipientCount = AudioChannelMatrix.deliveryRecipients(for: packet, personas: personas).count
            Task { @MainActor in
                let manager = VitaVoiceAudioManager.shared
                manager.recentPackets.insert(packet, at: 0)
                if manager.recentPackets.count > 24 { manager.recentPackets.removeLast() }
                manager.activeSpeakerLabel = label
                manager.sessionStatus =
                    "Sent \(priority.displayName) · \(encoded.count) B · \(recipientCount) recipient profile(s)"
                AudioGuidanceFeedbackEngine.speak(
                    priority == .emergencyAlert
                        ? "Emergency channel. \(message)"
                        : "Message routed on \(channel.channelName)."
                )
            }
        }
    }

    func openSpatialBridge(
        operatorLabel: String,
        responderLabel: String,
        incidentSummary: String
    ) {
        activeSpatialBridge = SpatialVoiceBridge(
            id: UUID(),
            operatorLabel: operatorLabel,
            responderLabel: responderLabel,
            incidentSummary: incidentSummary,
            openedAt: .now
        )
        if let spatial = AudioChannelMatrix.catalog.first(where: { $0.isSpatialGeofenced }),
           !subscribedChannels.contains(where: { $0.id == spatial.id })
        {
            subscribedChannels.append(spatial)
        }
        sessionStatus = "Spatial PTT · \(operatorLabel) ↔ \(responderLabel)"
        AudioGuidanceFeedbackEngine.speak("Direct bridge open. \(incidentSummary)")
    }

    func tearDownSpatialBridge() {
        activeSpatialBridge = nil
        subscribedChannels.removeAll { $0.isSpatialGeofenced }
    }

    func cutAllStreamsForPersonaShift() {
        stopPushToTalk()
        tearDownSpatialBridge()
        activeSpeakerLabel = nil
        sessionStatus = "Streams cut — rebinding channels…"
        refreshSubscriptions()
    }

    private func resolveChannel(
        priority: AudioStreamPriority,
        domain: MacroTenantDomain
    ) -> ActiveAudioChannel? {
        if priority == .administrativeWhisper {
            return AudioChannelMatrix.whisperChannel(domain: domain)
        }
        return subscribedChannels.first { $0.priority == priority }
            ?? subscribedChannels.first
    }
}

// MARK: - Background audio engine (Swift 6 — off MainActor)

private enum VitaVoicePacketEncoder: Sendable {
    static func encode(message: String, priority: AudioStreamPriority) -> Data {
        var payload = Data()
        payload.append(UInt8(priority.rawValue))
        if let bytes = message.data(using: .utf8) {
            payload.append(bytes)
        }
        return payload
    }
}

enum VoiceEngineError: Error, LocalizedError {
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
            case .audioInputUnavailable:
                "Microphone input is unavailable — check that mic permission is granted."
        }
    }
}

private final class VoiceAudioEngineBox: @unchecked Sendable {
    private var engine: AVAudioEngine?

    static func startRecording(in box: VoiceAudioEngineBox) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)
        #endif

        let engine = AVAudioEngine()
        // Touch `inputNode` first so the engine graph realizes a valid I/O node. Starting an
        // engine with no realized node throws an uncatchable CoreAudio NSException (iPad crash).
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw VoiceEngineError.audioInputUnavailable
        }
        // No-op tap keeps the input node live without routing mic → speaker (no feedback loop).
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
        engine.prepare()
        try engine.start()
        box.engine = engine
    }

    static func stopRecording(in box: VoiceAudioEngineBox) {
        box.engine?.inputNode.removeTap(onBus: 0)
        box.engine?.stop()
        box.engine = nil
    }
}
