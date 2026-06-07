import SwiftUI

/// Compact Vita Voice strip for the dynamic shell (Sprint FFFF).
struct VoiceCommsOverlayView: View {
    @ObservedObject private var voice = VitaVoiceAudioManager.shared
    @ObservedObject private var vault = MasterVaultProfileManager.shared
    @State private var draftMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Vita Voice", systemImage: "waveform.circle.fill")
                    .font(DesignSystem.Typography.bodyEmphasized)
                Spacer()
                if voice.isPTTActive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("PTT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                }
            }

            Text(voice.sessionStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !voice.subscribedChannels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(voice.subscribedChannels) { channel in
                            channelChip(channel)
                        }
                    }
                }
            }

            if let bridge = voice.activeSpatialBridge {
                spatialBridgeCard(bridge)
            }

            HStack(spacing: 10) {
                pttButton
                whisperButton
            }

            if let packet = voice.recentPackets.first {
                Text("Last: \(packet.senderLabel) · \(packet.priority.displayName)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .onAppear { voice.refreshSubscriptions() }
        .onChange(of: vault.activePersonaID) { _, _ in
            voice.cutAllStreamsForPersonaShift()
        }
        .onChange(of: vault.activeMacroDomain) { _, _ in
            voice.cutAllStreamsForPersonaShift()
        }
    }

    private var pttButton: some View {
        Button {
            if voice.isPTTActive {
                voice.stopPushToTalk()
                if !draftMessage.isEmpty {
                    voice.broadcast(message: draftMessage, priority: .standardChat)
                    draftMessage = ""
                }
            } else {
                voice.startPushToTalk()
            }
        } label: {
            Label(
                voice.isPTTActive ? "Release PTT" : "Hold to talk",
                systemImage: voice.isPTTActive ? "mic.fill" : "mic.circle"
            )
        }
        .buttonStyle(.borderedProminent)
    }

    private var whisperButton: some View {
        Button {
            voice.broadcast(
                message: "Macro directive — all department heads acknowledge.",
                priority: .administrativeWhisper,
                senderLabel: vault.activePersona?.positionTitle
            )
        } label: {
            Label("PM whisper", systemImage: "person.2.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .disabled(vault.activePersona?.rankTier != .administrative
            && vault.activeMacroDomain != .technicalCrews)
    }

    private func channelChip(_ channel: ActiveAudioChannel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(channel.channelName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(channel.priority.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private func spatialBridgeCard(_ bridge: SpatialVoiceBridge) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(bridge.operatorLabel) ↔ \(bridge.responderLabel)")
                    .font(.caption.weight(.semibold))
                Text(bridge.incidentSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
