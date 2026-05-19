import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color Extensions for RatioVita Design System

extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (e.g., "#FF0000" or "FF0000")
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        var int: UInt64 = 0
        guard Scanner(string: digits).scanHexInt64(&int) else {
            self.init(.sRGB, red: 0.53, green: 0.53, blue: 0.53, opacity: 1)
            return
        }
        let a, r, g, b: UInt64
        switch digits.count {
            case 8: // AARRGGBB
                (a, r, g, b) = (
                    (int & 0xFF00_0000) >> 24,
                    (int & 0x00FF_0000) >> 16,
                    (int & 0x0000_FF00) >> 8,
                    int & 0x0000FF
                )
            case 6: // RRGGBB
                (a, r, g, b) = (255, (int & 0xFF0000) >> 16, (int & 0x00FF00) >> 8, int & 0x0000FF)
            default:
                (a, r, g, b) = (255, 136, 136, 136)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    /// Convert Color to hex string
    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        let resolved = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        #elseif canImport(AppKit)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return "#888888"
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        #endif
    }
}

// MARK: - RatioVita Design System Colors

extension Color {
    /// Primary brand colors
    static let ratioVitaPrimary = Color(hex: "#2E7D32") // Forest Green
    static let ratioVitaSecondary = Color(hex: "#4CAF50") // Light Green
    static let ratioVitaAccent = Color(hex: "#FF9800") // Orange
    
    /// Status colors
    static let ratioVitaSuccess = Color(hex: "#4CAF50") // Green
    static let ratioVitaWarning = Color(hex: "#FF9800") // Orange
    static let ratioVitaError = Color(hex: "#F44336") // Red
    static let ratioVitaInfo = Color(hex: "#2196F3") // Blue
    
    /// Positive amounts (income / credits) vs negative (expenses / debits) for signed currency display.
    static func ratioVitaSignedCurrencyAmount(_ amount: Decimal) -> Color {
        if amount > 0 { return ratioVitaSuccess }
        if amount < 0 { return ratioVitaError }
        return Color.secondary
    }

    /// Neutral colors
    static let ratioVitaBackground = Color(hex: "#FAFAFA") // Light Gray
    static let ratioVitaSurface = Color(hex: "#FFFFFF") // White
    static let ratioVitaBorder = Color(hex: "#E0E0E0") // Light Gray

    /// Text colors (light-mode defaults; prefer `ratioVitaTextSecondary` adaptive below for UI)
    static let ratioVitaTextPrimary = Color(hex: "#212121") // Dark Gray
    static let ratioVitaTextPrimaryFixed = Color(hex: "#212121")
    static let ratioVitaTextSecondaryFixed = Color(hex: "#757575")
    static let ratioVitaTextDisabled = Color(hex: "#BDBDBD") // Light Gray
}

// MARK: - Dark Mode Support

extension Color {
    /// Adaptive color that changes based on color scheme
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
                case .dark:
                    UIColor(dark)
                default:
                    UIColor(light)
            }
        })
        #elseif canImport(AppKit)
        // Dynamic NSColor that adapts to appearance (darkAqua vs aqua)
        let dynamic = NSColor(name: NSColor.Name("Adaptive-\(UUID().uuidString)")) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                NSColor(dark)
            } else {
                NSColor(light)
            }
        }
        return Color(dynamic)
        #endif
    }
    
    /// RatioVita adaptive colors
    #if os(iOS) || os(visionOS)
    /// iPhone / iPad (OLED): true black in dark mode; cards rely on borders / overlays for separation.
    static let ratioVitaAdaptiveBackground = adaptive(
        light: Color(hex: "#FAFAFA"),
        dark: Color(hex: "#000000")
    )

    static let ratioVitaAdaptiveSurface = adaptive(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#000000")
    )
    #else
    static let ratioVitaAdaptiveBackground = adaptive(
        light: Color(hex: "#FAFAFA"),
        dark: Color(hex: "#121212")
    )

    static let ratioVitaAdaptiveSurface = adaptive(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#2C2C2E") // slightly elevated vs background for cards
    )
    #endif

    static let ratioVitaAdaptiveText = adaptive(
        light: Color(hex: "#212121"),
        dark: Color(hex: "#FFFFFF")
    )

    /// Secondary / supporting text (must stay legible on dark surfaces — not fixed #757575).
    static let ratioVitaTextSecondary = adaptive(
        light: Color(hex: "#616161"),
        dark: Color(hex: "#C4C4C4")
    )

    /// Muted text (captions on tinted rows).
    static let ratioVitaTextTertiary = adaptive(
        light: Color(hex: "#9E9E9E"),
        dark: Color(hex: "#9E9E9E")
    )

    /// Dividers and hairlines.
    static let ratioVitaAdaptiveBorder = adaptive(
        light: Color(hex: "#E0E0E0"),
        dark: Color(hex: "#48484A")
    )

    /// Disabled controls (adaptive).
    static let ratioVitaTextDisabledAdaptive = adaptive(
        light: Color(hex: "#BDBDBD"),
        dark: Color(hex: "#636366")
    )
}

// MARK: - Tag Colors (from older project)

extension Color {
    /// Predefined tag colors for categorization
    static let tagColors: [Color] = [
        Color(hex: "#F44336"), // Red
        Color(hex: "#E91E63"), // Pink
        Color(hex: "#9C27B0"), // Purple
        Color(hex: "#673AB7"), // Deep Purple
        Color(hex: "#3F51B5"), // Indigo
        Color(hex: "#2196F3"), // Blue
        Color(hex: "#03A9F4"), // Light Blue
        Color(hex: "#00BCD4"), // Cyan
        Color(hex: "#009688"), // Teal
        Color(hex: "#4CAF50"), // Green
        Color(hex: "#8BC34A"), // Light Green
        Color(hex: "#CDDC39"), // Lime
        Color(hex: "#FFEB3B"), // Yellow
        Color(hex: "#FFC107"), // Amber
        Color(hex: "#FF9800"), // Orange
        Color(hex: "#FF5722"), // Deep Orange
        Color(hex: "#795548"), // Brown
        Color(hex: "#607D8B"), // Blue Grey
        Color(hex: "#9E9E9E"), // Grey
    ]
    
    /// Get a tag color by index
    static func tagColor(at index: Int) -> Color {
        tagColors[index % tagColors.count]
    }
}
