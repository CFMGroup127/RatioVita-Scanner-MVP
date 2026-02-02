import SwiftUI
import Combine

// MARK: - Theme Manager

/// Manages app-wide theming and color schemes
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
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
    
    // MARK: - Persistence
    
    private func saveTheme() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(accentColor.toHex(), forKey: "accentColor")
        UserDefaults.standard.set(customTheme.rawValue, forKey: "customTheme")
    }
    
    private func loadTheme() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        if let accentHex = UserDefaults.standard.string(forKey: "accentColor") {
            accentColor = Color(hex: accentHex)
        }
        
        if let themeRawValue = UserDefaults.standard.string(forKey: "customTheme"),
           let theme = RatioVitaTheme(rawValue: themeRawValue) {
            customTheme = theme
        }
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
            return .ratioVitaPrimary
        case .forest:
            return Color(hex: "#2E7D32")
        case .ocean:
            return Color(hex: "#1976D2")
        case .sunset:
            return Color(hex: "#FF5722")
        case .monochrome:
            return Color(hex: "#424242")
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .default:
            return .ratioVitaSecondary
        case .forest:
            return Color(hex: "#4CAF50")
        case .ocean:
            return Color(hex: "#03A9F4")
        case .sunset:
            return Color(hex: "#FF9800")
        case .monochrome:
            return Color(hex: "#757575")
        }
    }
    
    var accentColor: Color {
        switch self {
        case .default:
            return .ratioVitaAccent
        case .forest:
            return Color(hex: "#8BC34A")
        case .ocean:
            return Color(hex: "#00BCD4")
        case .sunset:
            return Color(hex: "#FFC107")
        case .monochrome:
            return Color(hex: "#9E9E9E")
        }
    }
}

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .accentColor(themeManager.accentColor)
    }
}

extension View {
    /// Apply RatioVita theme to the view
    func ratioVitaTheme() -> some View {
        self.modifier(ThemeModifier())
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                        .onChange(of: themeManager.isDarkMode) { _ in
                            themeManager.toggleDarkMode()
                        }
                }
                
                Section("Theme") {
                    ForEach(RatioVitaTheme.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.secondaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Spacer()
                            
                            if themeManager.customTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            themeManager.setCustomTheme(theme)
                        }
                    }
                }
                
                Section("Accent Color") {
                    HStack {
                        Text("Accent Color")
                        
                        Spacer()
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Color.tagColors.prefix(8), id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.ratioVitaAdaptiveText, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        themeManager.setAccentColor(color)
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Theme Settings")
        }
        .ratioVitaTheme()
    }
}

#Preview("Theme Preview") {
    ThemePreview()
}
