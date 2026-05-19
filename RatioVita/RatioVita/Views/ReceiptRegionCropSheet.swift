import SwiftUI

/// Sheet token for **region crop** presentation (`ReceiptRegionCropSheet`).
struct ReceiptPageRegionCropToken: Identifiable, Hashable {
    let id: UUID
}

/// Axis-aligned **region of interest** crop for a single `ReceiptImage` (EP statement strip, etc.).
struct ReceiptRegionCropSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var image: ReceiptImage

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var boxW: CGFloat = 320
    @State private var boxH: CGFloat = 420

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Drag a rectangle on the page, then tap **Apply**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ZStack(alignment: .topLeading) {
                    if let plat = image.platformImage {
                        Image(rvImage: plat)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: CropBoxSizeKey.self, value: g.size)
                                }
                            )
                            .onPreferenceChange(CropBoxSizeKey.self) { s in
                                if s.width > 1, s.height > 1 {
                                    boxW = s.width
                                    boxH = s.height
                                }
                            }
                            .coordinateSpace(name: "roiCrop")

                        if let a = dragStart, let b = dragCurrent {
                            let r = CGRect(
                                x: min(a.x, b.x),
                                y: min(a.y, b.y),
                                width: max(4, abs(b.x - a.x)),
                                height: max(4, abs(b.y - a.y))
                            )
                            Path { p in p.addRect(r) }
                                .stroke(Color.orange, lineWidth: 2)
                                .allowsHitTesting(false)
                        }
                    } else {
                        ContentUnavailableView("No image", systemImage: "photo")
                    }
                }
                .frame(maxHeight: 520)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named("roiCrop"))
                        .onChanged { g in
                            if dragStart == nil { dragStart = g.startLocation }
                            dragCurrent = g.location
                        }
                        .onEnded { _ in }
                )
            }
            .padding()
            .navigationTitle("Region crop")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { applyCropTapped() }
                            .fontWeight(.semibold)
                            .disabled(dragStart == nil || dragCurrent == nil)
                    }
                }
        }
    }

    private func applyCropTapped() {
        guard let plat = image.platformImage else { return }
        guard let a = dragStart, let b = dragCurrent else { return }
        let w = max(boxW, 1)
        let h = max(boxH, 1)
        let minX = min(a.x, b.x) / w
        let minY = min(a.y, b.y) / h
        let rw = max(0.04, abs(b.x - a.x) / w)
        let rh = max(0.04, abs(b.y - a.y) / h)
        let norm = CGRect(
            x: min(0.96, max(0, minX)),
            y: min(0.96, max(0, minY)),
            width: min(1 - minX, rw),
            height: min(1 - minY, rh)
        )
        guard let cropped = ReceiptImageRasterOps.cropTopLeftNormalized(plat, rect: norm) else { return }

        Task { @MainActor in
            do {
                let result = try await ReceiptScanPipeline.processImported(
                    image: cropped,
                    ocrEnabled: true,
                    compressionEnabled: true
                )
                if let page = result.scannedPages.first {
                    image.replaceRasterAndOCR(image: page.image, ocrText: page.ocrText, compressionQuality: 0.9)
                } else {
                    image.replaceRasterAndOCR(image: cropped, ocrText: nil, compressionQuality: 0.9)
                }
            } catch {
                image.replaceRasterAndOCR(image: cropped, ocrText: nil, compressionQuality: 0.9)
            }
            dismiss()
        }
    }
}

private struct CropBoxSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let n = nextValue()
        if n.width > 0, n.height > 0 { value = n }
    }
}
