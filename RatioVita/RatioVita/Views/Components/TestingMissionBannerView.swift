import SwiftUI

/// Persistent tester mission HUD (debug builds / cockpit toggle).
struct TestingMissionBannerView: View {
    @ObservedObject private var mission = TestingMissionManager.shared

    var body: some View {
        if mission.isHUDVisible, let line = mission.missionContextLine {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption.weight(.semibold))
                Text("Mission: \(line)")
                    .font(.caption)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.orange.opacity(0.5)),
                alignment: .bottom
            )
            .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth)
        }
    }
}
