import SwiftUI

/// Presents a system share flow for a file URL created by batch export.
struct ShareExportSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ShareLink(
                    item: url,
                    preview: SharePreview(url.lastPathComponent, image: Image(systemName: "doc.richtext"))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(url.lastPathComponent)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Export")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
