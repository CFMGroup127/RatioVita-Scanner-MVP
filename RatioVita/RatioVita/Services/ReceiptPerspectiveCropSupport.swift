#if os(iOS)
import CoreImage
import SwiftUI
import UIKit

/// Perspective **squaring** for receipt scans (`CIPerspectiveCorrection`). Corners are **normalized** 0…1 with a
/// **top-left** origin (matching the overlay).
enum ReceiptPerspectiveCropRenderer {
    static func warp(
        image: UIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint
    ) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg).oriented(forExifOrientation: Int32(image.imageOrientation.rawValue))
        let ext = ci.extent
        let w = ext.width
        let h = ext.height

        func ciVector(fromTopLeftNormalized p: CGPoint) -> CIVector {
            let x = ext.minX + p.x * w
            let y = ext.maxY - p.y * h
            return CIVector(x: x, y: y)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(ciVector(fromTopLeftNormalized: topLeft), forKey: "inputTopLeft")
        filter.setValue(ciVector(fromTopLeftNormalized: topRight), forKey: "inputTopRight")
        filter.setValue(ciVector(fromTopLeftNormalized: bottomRight), forKey: "inputBottomRight")
        filter.setValue(ciVector(fromTopLeftNormalized: bottomLeft), forKey: "inputBottomLeft")

        guard let out = filter.outputImage else { return nil }
        let ctx = CIContext(options: nil)
        guard let cgOut = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cgOut, scale: image.scale, orientation: .up)
    }
}

/// Draggable-corner perspective crop for one `ReceiptImage`.
struct ReceiptPerspectiveCropSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var image: ReceiptImage

    @State private var topLeft = CGPoint(x: 0.06, y: 0.06)
    @State private var topRight = CGPoint(x: 0.94, y: 0.06)
    @State private var bottomRight = CGPoint(x: 0.94, y: 0.94)
    @State private var bottomLeft = CGPoint(x: 0.06, y: 0.94)
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let imgW = geo.size.width
                let imgH = geo.size.height * 0.72
                ZStack(alignment: .topLeading) {
                    if let plat = image.platformImage {
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: plat)
                                .resizable()
                                .scaledToFit()
                                .frame(width: imgW, height: imgH)
                                .clipped()

                            Path { p in
                                p.move(to: CGPoint(x: topLeft.x * imgW, y: topLeft.y * imgH))
                                p.addLine(to: CGPoint(x: topRight.x * imgW, y: topRight.y * imgH))
                                p.addLine(to: CGPoint(x: bottomRight.x * imgW, y: bottomRight.y * imgH))
                                p.addLine(to: CGPoint(x: bottomLeft.x * imgW, y: bottomLeft.y * imgH))
                                p.closeSubpath()
                            }
                            .stroke(Color.orange, lineWidth: 2)

                            cornerKnob(imgW: imgW, imgH: imgH, point: $topLeft)
                            cornerKnob(imgW: imgW, imgH: imgH, point: $topRight)
                            cornerKnob(imgW: imgW, imgH: imgH, point: $bottomRight)
                            cornerKnob(imgW: imgW, imgH: imgH, point: $bottomLeft)
                        }
                        .frame(width: imgW, height: imgH)
                        .coordinateSpace(name: "cropSpace")

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(Color.red)
                                .padding(.top, imgH + 8)
                        }
                    } else {
                        ContentUnavailableView("No image", systemImage: "photo")
                    }
                }
            }
            .padding()
            .navigationTitle("Perspective crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyTapped() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func cornerKnob(imgW: CGFloat, imgH: CGFloat, point: Binding<CGPoint>) -> some View {
        let center = CGPoint(x: point.wrappedValue.x * imgW, y: point.wrappedValue.y * imgH)
        return Circle()
            .fill(Color.white)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.orange, lineWidth: 2))
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cropSpace"))
                    .onChanged { g in
                        let nx = min(0.98, max(0.02, g.location.x / imgW))
                        let ny = min(0.98, max(0.02, g.location.y / imgH))
                        point.wrappedValue = CGPoint(x: nx, y: ny)
                    }
            )
    }

    private func applyTapped() {
        errorText = nil
        guard let plat = image.platformImage else {
            errorText = "Image missing."
            return
        }
        guard let out = ReceiptPerspectiveCropRenderer.warp(
            image: plat,
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft
        ) else {
            errorText = "Could not build corrected image."
            return
        }
        image.replaceEncodedImage(out, compressionQuality: 0.92)
        dismiss()
    }
}
#endif
