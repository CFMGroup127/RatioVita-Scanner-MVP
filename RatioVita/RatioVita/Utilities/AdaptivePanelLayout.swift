import SwiftUI

/// Shared layout helpers for detail panels — prevents horizontal text runoff and window resize snaps.
enum AdaptivePanelLayout {
    static let detailMinWidth: CGFloat = 450
    static let detailIdealWidth: CGFloat = 650
    static let detailMaxReadableWidth: CGFloat = 720
}

extension View {
    /// Word-wrap dynamic copy inside a detail column instead of expanding the window horizontally.
    func adaptiveDetailText() -> some View {
        lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Standard detail pane width band (macOS split views).
    func detailPanelFrame(alignment: Alignment = .topLeading) -> some View {
        frame(
            minWidth: AdaptivePanelLayout.detailMinWidth,
            idealWidth: AdaptivePanelLayout.detailIdealWidth,
            maxWidth: AdaptivePanelLayout.detailMaxReadableWidth,
            alignment: alignment
        )
    }

    /// Fills available space but caps readable line length for forms.
    func boundedDetailContent(alignment: Alignment = .topLeading) -> some View {
        frame(
            maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth,
            maxHeight: SafeLayoutBounds.maxWindowHeight,
            alignment: alignment
        )
    }
}

// MARK: - Labeled form rows (macOS production editor)

/// Left-aligned label + control row (avoids trailing-edge `Form` label truncation on macOS).
struct ProductionFormLabeledRow<Content: View>: View {
    let label: String
    var labelWidth: CGFloat = 148
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .multilineTextAlignment(.leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Left-aligned detail form (macOS)

/// Replaces trailing-edge `Form` controls on macOS detail panes.
struct LeftAlignedFormSection<Content: View, Footer: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footerView: () -> Footer

    init(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer footerView: @escaping () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.footer = footer
        self.content = content
        self.footerView = footerView
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .adaptiveDetailText()
            }
            footerView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
