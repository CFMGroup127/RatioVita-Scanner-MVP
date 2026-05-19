import SwiftUI

/// Pinch / scroll zoom for receipt page previews in Review.
struct ZoomableDocumentImageView: View {
    let image: RVImage
    var maxHeight: CGFloat = 520

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(rvImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .frame(minWidth: 280 * scale, minHeight: 200 * scale)
                .padding(DesignSystem.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight)
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(4, max(0.5, lastScale * value))
                }
                .onEnded { value in
                    lastScale = min(4, max(0.5, lastScale * value))
                    scale = lastScale
                }
        )
    }
}
