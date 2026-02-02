import SwiftUI

// MARK: - RatioVita Design System

/// Comprehensive design system for RatioVita_v2
struct DesignSystem {
    
    // MARK: - Typography
    
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let bodyEmphasized = Font.body.weight(.medium)
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }

    // MARK: - Sovereign Layout (Monday Ignition)

    /// 144.0 pt ceiling for Scanner and Receipts list headers (Sovereign Theme).
    struct Layout {
        static let topMargin: CGFloat = 144.0
        static let sovereignHeaderHeight: CGFloat = 144.0
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Apply a shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadow: ShadowStyle
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.ratioVitaAdaptiveSurface,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        shadow: ShadowStyle = DesignSystem.Shadow.small,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.md,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.md,
            trailing: DesignSystem.Spacing.md
        )
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(shadow)
    }
}

extension View {
    /// Apply card styling
    func cardStyle(
        backgroundColor: Color = Color.ratioVitaAdaptiveSurface,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        shadow: ShadowStyle = DesignSystem.Shadow.small,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.md,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.md,
            trailing: DesignSystem.Spacing.md
        )
    ) -> some View {
        self.modifier(CardStyle(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow,
            padding: padding
        ))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.ratioVitaPrimary,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.sm,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.sm,
            leading: DesignSystem.Spacing.lg,
            bottom: DesignSystem.Spacing.sm,
            trailing: DesignSystem.Spacing.lg
        )
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyEmphasized)
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.clear,
        foregroundColor: Color = Color.ratioVitaPrimary,
        borderColor: Color = Color.ratioVitaPrimary,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.sm,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.sm,
            leading: DesignSystem.Spacing.lg,
            bottom: DesignSystem.Spacing.sm,
            trailing: DesignSystem.Spacing.lg
        )
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyEmphasized)
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    let backgroundColor: Color
    
    init(
        text: String,
        color: Color = .white,
        backgroundColor: Color = Color.ratioVitaInfo
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

// MARK: - Predefined Status Badges

extension StatusBadge {
    static func success(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaSuccess)
    }
    
    static func warning(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaWarning)
    }
    
    static func error(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaError)
    }
    
    static func info(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaInfo)
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color
    let backgroundColor: Color
    let onTap: (() -> Void)?
    
    init(
        text: String,
        color: Color = Color.ratioVitaAdaptiveText,
        backgroundColor: Color = Color.ratioVitaBorder,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            Text(text)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(backgroundColor)
                .cornerRadius(DesignSystem.CornerRadius.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionText: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionText = actionText
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaAdaptiveText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(Color.ratioVitaTextSecondary)
                }
            }
            
            Spacer()
            
            if let action = action, let actionText = actionText {
                Button(action: action) {
                    Text(actionText)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(Color.ratioVitaPrimary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}
