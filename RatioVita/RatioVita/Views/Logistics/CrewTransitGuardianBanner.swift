import SwiftUI

/// Real-time crew alert surface — streams `transit_exceptions` written by the VitaLogic ingestion engine.
struct CrewTransitGuardianBanner: View {
    let productionId: String
    var activeCallSheetId: String?

    @ObservedObject private var streamService = TransitGuardianStreamService.shared
    @ObservedObject private var liveCoordinator = ProductionLogisticsLiveCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = streamService.activeBannerMessage {
                alertBanner(message)
            } else if streamService.isListening {
                liveStatusBanner
            }

            if let summary = streamService.lastIngestionSummary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: refreshListeners)
        .onChange(of: productionId) { _, _ in refreshListeners() }
        .onChange(of: activeCallSheetId) { _, _ in refreshListeners() }
    }

    private func refreshListeners() {
        liveCoordinator.syncActiveProduction(
            productionId: productionId,
            callSheetId: activeCallSheetId
        )
    }

    private func alertBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arterial Traffic Blockage Detected")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Critical transit alert")
    }

    private var liveStatusBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(streamService.isFirebaseLinked ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(streamService.isFirebaseLinked
                ? "Logistical Guardian live — monitoring transit exceptions"
                : "Firebase not configured — add GoogleService-Info.plist or __firebase_config")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
