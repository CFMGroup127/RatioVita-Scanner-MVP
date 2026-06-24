import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum SovereignQRCodeRenderer {
    static func makeImage(from payload: String, scale: CGFloat = 8) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }

    @ViewBuilder
    static func qrView(for payload: String, scale: CGFloat = 8) -> some View {
        if let cgImage = makeImage(from: payload, scale: scale) {
            qrImageView(cgImage)
        } else {
            ContentUnavailableView("QR unavailable", systemImage: "qrcode")
        }
    }

    @ViewBuilder
    private static func qrImageView(_ cgImage: CGImage) -> some View {
        Image(decorative: cgImage, scale: 1, orientation: .up)
            .resizable()
            .scaledToFit()
            .accessibilityLabel("Sovereign onboarding QR code")
    }
}
