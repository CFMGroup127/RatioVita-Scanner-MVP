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
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var int: UInt64 = 0
        Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 8: // ARGB
            (a, r, g, b) = ((int & 0xFF000000) >> 24, (int & 0x00FF0000) >> 16, (int & 0x0000FF00) >> 8, int & 0x0000FF)
        case 6: // RGB
            (a, r, g, b) = (255, (int & 0xFF0000) >> 16, (int & 0x00FF00) >> 8, int & 0x0000FF)
        default:
            (a, r, g, b) = (255, 136, 136, 136)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    
    /// Convert Color to hex string
    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
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
    
    /// Neutral colors
    static let ratioVitaBackground = Color(hex: "#FAFAFA") // Light Gray
    static let ratioVitaSurface = Color(hex: "#FFFFFF") // White
    static let ratioVitaBorder = Color(hex: "#E0E0E0") // Light Gray
    
    /// Text colors
    static let ratioVitaTextPrimary = Color(hex: "#212121") // Dark Gray
    static let ratioVitaTextSecondary = Color(hex: "#757575") // Medium Gray
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
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #elseif canImport(AppKit)
        // Dynamic NSColor that adapts to appearance (darkAqua vs aqua)
        let dynamic = NSColor(name: NSColor.Name("Adaptive-\(UUID().uuidString)")) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        }
        return Color(dynamic)
        #endif
    }
    
    /// RatioVita adaptive colors
    static let ratioVitaAdaptiveBackground = adaptive(
        light: Color(hex: "#FAFAFA"),
        dark: Color(hex: "#121212")
    )
    
    static let ratioVitaAdaptiveSurface = adaptive(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#1E1E1E")
    )
    
    static let ratioVitaAdaptiveText = adaptive(
        light: Color(hex: "#212121"),
        dark: Color(hex: "#FFFFFF")
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
