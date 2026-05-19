import Combine
import SwiftUI

// MARK: - Theme Manager

/// Manages app-wide theming and color schemes
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Bumped when persisted accent/theme values need one-time correction (e.g. bad hex round-trips).
    private static let themePersistenceVersion = 1
    private static let themePersistenceVersionKey = "com.ratiovita.themePersistenceVersion"

    @Published var isDarkMode: Bool = false
    @Published var accentColor: Color = .ratioVitaPrimary
    @Published var customTheme: RatioVitaTheme = .default
    
    private init() {
        // Load saved preferences
        loadTheme()
    }
    
    // MARK: - Theme Management
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        saveTheme()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveTheme()
    }
    
    func setCustomTheme(_ theme: RatioVitaTheme) {
        customTheme = theme
        saveTheme()
    }

    /// Two-way binding for Settings / Theme UI (avoids double-toggle bugs).
    var darkModeBinding: Binding<Bool> {
        Binding(
            get: { self.isDarkMode },
            set: { newValue in
                self.isDarkMode = newValue
                self.saveTheme()
            }
        )
    }

    // MARK: - Persistence
    
    private func saveTheme() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(accentColor.toHex(), forKey: "accentColor")
        UserDefaults.standard.set(customTheme.rawValue, forKey: "customTheme")
    }
    
    private func loadTheme() {
        migrateThemePersistenceIfNeeded()

        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")

        if let accentHex = UserDefaults.standard.string(forKey: "accentColor") {
            accentColor = Color(hex: accentHex)
        }

        if let themeRawValue = UserDefaults.standard.string(forKey: "customTheme"),
           let theme = RatioVitaTheme(rawValue: themeRawValue)
        {
            customTheme = theme
        }
    }

    /// Older builds parsed `#RRGGBB` incorrectly (count included `#`), so many saved accents became `#888888`.
    private func migrateThemePersistenceIfNeeded() {
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: Self.themePersistenceVersionKey)
        guard current < Self.themePersistenceVersion else { return }

        if let hex = defaults.string(forKey: "accentColor")?.uppercased(),
           hex == "#888888" || hex == "888888"
        {
            defaults.removeObject(forKey: "accentColor")
        }

        defaults.set(Self.themePersistenceVersion, forKey: Self.themePersistenceVersionKey)
    }
}

// MARK: - RatioVita Themes

enum RatioVitaTheme: String, CaseIterable {
    case `default` = "Default"
    case forest = "Forest"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case monochrome = "Monochrome"
    
    var displayName: String {
        rawValue
    }
    
    var primaryColor: Color {
        switch self {
            case .default:
                .ratioVitaPrimary
            case .forest:
                Color(hex: "#2E7D32")
            case .ocean:
                Color(hex: "#1976D2")
            case .sunset:
                Color(hex: "#FF5722")
            case .monochrome:
                Color(hex: "#424242")
        }
    }
    
    var secondaryColor: Color {
        switch self {
            case .default:
                .ratioVitaSecondary
            case .forest:
                Color(hex: "#4CAF50")
            case .ocean:
                Color(hex: "#03A9F4")
            case .sunset:
                Color(hex: "#FF9800")
            case .monochrome:
                Color(hex: "#757575")
        }
    }
    
    var accentColor: Color {
        switch self {
            case .default:
                .ratioVitaAccent
            case .forest:
                Color(hex: "#8BC34A")
            case .ocean:
                Color(hex: "#00BCD4")
            case .sunset:
                Color(hex: "#FFC107")
            case .monochrome:
                Color(hex: "#9E9E9E")
        }
    }
}

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

private struct BrandAccentKey: EnvironmentKey {
    static let defaultValue = Color.ratioVitaPrimary
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }

    /// Primary brand tint from **Appearance → theme** (Forest, Ocean, etc.).
    var brandAccent: Color {
        get { self[BrandAccentKey.self] }
        set { self[BrandAccentKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager)
            .environment(\.brandAccent, themeManager.customTheme.primaryColor)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .tint(themeManager.customTheme.primaryColor)
            .accentColor(themeManager.accentColor)
    }
}

extension View {
    /// Apply RatioVita theme to the view
    func ratioVitaTheme() -> some View {
        modifier(ThemeModifier())
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    private let accentChoices = Array(Color.tagColors.prefix(16))

    private var accentColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 40, maximum: 56), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    appearanceBlock
                    themeBlock
                    accentBlock
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
            .navigationTitle("Appearance")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .ratioVitaTheme()
    }

    private var appearanceBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Appearance")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Toggle("Dark Mode", isOn: themeManager.darkModeBinding)
                .font(DesignSystem.Typography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(sectionChrome)
    }

    private var themeBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Theme")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)

            ForEach(RatioVitaTheme.allCases, id: \.self) { theme in
                themeRow(theme)
            }

            Text("Updates primary tint across lists, buttons, and highlights.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(sectionChrome)
    }

    private var accentBlock: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Accent color")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)

            LazyVGrid(columns: accentColumns, spacing: 12) {
                ForEach(Array(accentChoices.enumerated()), id: \.offset) { _, color in
                    accentChip(color)
                }
            }

            Text("Used for toggles, links, and secondary emphasis.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(sectionChrome)
    }

    private var sectionChrome: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
            .fill(Color.ratioVitaAdaptiveSurface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.55), lineWidth: 1)
            )
            .shadow(DesignSystem.Shadow.small)
    }

    @ViewBuilder
    private func themeRow(_ theme: RatioVitaTheme) -> some View {
        let selected = themeManager.customTheme == theme
        HStack(spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: theme.primaryColor.opacity(0.45), radius: 8, y: 4)
                .compositingGroup()

            VStack(alignment: .leading, spacing: 8) {
                Text(theme.displayName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(Color.ratioVitaAdaptiveText)

                HStack(spacing: 10) {
                    themeSwatch(theme.primaryColor)
                    themeSwatch(theme.secondaryColor)
                    themeSwatch(theme.accentColor)
                }
            }

            Spacer(minLength: 8)

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.primaryColor)
                    .accessibilityLabel("Selected")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(selected ? theme.primaryColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            themeManager.setCustomTheme(theme)
        }
    }

    private func themeSwatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.ratioVitaAdaptiveBorder, lineWidth: 0.5))
            .shadow(color: color.opacity(0.35), radius: 3, y: 1)
            .compositingGroup()
    }

    private func accentChip(_ color: Color) -> some View {
        let matches = themeManager.accentColor.toHex() == color.toHex()
        return Button {
            themeManager.setAccentColor(color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay {
                    if matches {
                        ZStack {
                            Circle()
                                .stroke(Color.ratioVitaAdaptiveText, lineWidth: 3)
                                .frame(width: 46, height: 46)
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                    }
                }
                .shadow(color: color.opacity(0.35), radius: 4, y: 2)
                .compositingGroup()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accent \(color.toHex())")
    }
}

#Preview("Theme Preview") {
    ThemePreview()
}
