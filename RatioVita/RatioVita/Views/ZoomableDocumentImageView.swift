import SwiftUI

/// Pinch / scroll zoom for receipt page previews in Review — fits inside column bounds by default.
struct ZoomableDocumentImageView: View {
    let image: RVImage
    /// Pass the page id so zoom resets when the user selects a different page.
    var imageID: UUID?
    var maxHeight: CGFloat = 520

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let canvasWidth = max(geometry.size.width, 1)
            ScrollView([.horizontal, .vertical]) {
                Image(rvImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: canvasWidth, maxHeight: maxHeight)
                    .scaleEffect(scale)
                    .padding(DesignSystem.Spacing.sm)
            }
            .frame(width: canvasWidth, height: maxHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight)
        .clipped()
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(4, max(1, lastScale * value))
                }
                .onEnded { value in
                    lastScale = min(4, max(1, lastScale * value))
                    scale = lastScale
                }
        )
        .onAppear { resetZoom() }
        .onChange(of: imageID) { _, _ in resetZoom() }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
    }
}
