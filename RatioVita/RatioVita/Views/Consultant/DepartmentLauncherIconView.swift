import SwiftUI

/// Composited launcher tile: tactical glyph + RatioVita logo bar (Sprint QOO).
struct DepartmentLauncherIconView: View {
    let profile: LauncherShortcutProfile
    var size: CGFloat = 72
    var cornerRadius: CGFloat = 16

    private var glyphStyle: (symbol: String, color: Color) {
        AppIconAssetRegistry.glyphStyle(profile.departmentGlyph)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppIconAssetRegistry.graphiteBackground)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            VStack(spacing: 0) {
                Spacer(minLength: size * 0.12)
                Image(systemName: glyphStyle.symbol)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(glyphStyle.color)
                    .shadow(color: glyphStyle.color.opacity(0.45), radius: 6)
                Spacer(minLength: size * 0.08)
                logoBar
                    .frame(height: size * 0.28)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(profile.desktopLabel)
    }

    @ViewBuilder
    private var logoBar: some View {
        if LauncherBrandAssets.hasLogoMark(named: profile.systemLogoAsset) {
            Image(profile.systemLogoAsset)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 1) {
                Text("Ratio")
                    .font(.system(size: size * 0.09, weight: .bold, design: .rounded))
                Text("Vita")
                    .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
            }
            .foregroundStyle(AppIconAssetRegistry.logoBarSilver)
        }
    }
}

enum LauncherBrandAssets {
    static func hasLogoMark(named: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: named) != nil
        #elseif canImport(AppKit)
        NSImage(named: named) != nil
        #else
        false
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DepartmentLauncherDockView: View {
    var department: IndustryDepartmentScope?
    var tier: ConsultantTier?
    var profilesOverride: [LauncherShortcutProfile]?
    var onLaunch: (LauncherModuleIntent) -> Void

    @ObservedObject private var session = ConsultantSessionManager.shared

    private var resolvedProfiles: [LauncherShortcutProfile] {
        if let profilesOverride { return profilesOverride }
        return DepartmentScopeController.visibleShortcutProfiles(
            hat: session.activeOperationalHat,
            department: department,
            consultantTier: tier,
            temporalGrant: nil,
            macroDomain: MasterVaultProfileManager.shared.activeMacroDomain
        )
    }

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 110), spacing: 14),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Department consoles", systemImage: "square.grid.3x3.fill")
                    .font(DesignSystem.Typography.bodyEmphasized)
                Spacer()
                Text(ScopedWidgetRegistry.rankLabel(
                    hat: session.activeOperationalHat,
                    department: department,
                    consultantTier: tier
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Text(
                "Tap to open an isolated workspace. Add to Home Screen via Shortcuts app using the deep link shown on long-press (iOS)."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(resolvedProfiles) { profile in
                    Button {
                        onLaunch(profile.moduleIntent)
                    } label: {
                        VStack(spacing: 6) {
                            DepartmentLauncherIconView(profile: profile, size: 80)
                            Text(profile.desktopLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.ratioVitaAdaptiveText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    #if os(iOS)
                        .contextMenu {
                            if let link = NativeLauncherShortcutManager.deepLinkURL(for: profile) {
                                Text(link.absoluteString)
                                Button("Copy deep link") {
                                    UIPasteboard.general.string = link.absoluteString
                                }
                            }
                        }
                    #endif
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }
}
