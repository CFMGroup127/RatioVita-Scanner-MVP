import SwiftUI

/// Real-time crew alert surface — streams `transit_exceptions` written by the VitaLogic ingestion engine.
struct CrewTransitGuardianBanner: View {
    let productionId: String
    var activeCallSheetId: String?

    @StateObject private var streamService = TransitGuardianStreamService.shared

    var body: some View {
        Group {
            if let message = streamService.activeBannerMessage {
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
        }
        .onAppear {
            streamService.startListening(productionId: productionId, callSheetId: activeCallSheetId)
        }
        .onChange(of: productionId) { _, newValue in
            streamService.startListening(productionId: newValue, callSheetId: activeCallSheetId)
        }
        .onChange(of: activeCallSheetId) { _, newValue in
            streamService.startListening(productionId: productionId, callSheetId: newValue)
        }
    }
}
