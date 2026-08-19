import CoreImage
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum DocumentFilterMode: String, CaseIterable, Identifiable, Sendable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "B&W Document"

    var id: String { rawValue }
}

#if canImport(UIKit) || canImport(AppKit)
enum DocumentEnhancementFilter {
    /// Applies document-specific cleanup (shadow reduction, contrast boost, and grayscale / thresholding).
    static func enhanceDocument(_ image: RVImage, mode: DocumentFilterMode = .blackAndWhite) -> RVImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let context = CIContext(options: nil)
        var outputImage = ciImage

        switch mode {
        case .color:
            outputImage = outputImage
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.15,
                    kCIInputBrightnessKey: 0.05,
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.6,
                ])

        case .grayscale:
            outputImage = outputImage
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.25,
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.8,
                ])

        case .blackAndWhite:
            outputImage = outputImage
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.6,
                    kCIInputBrightnessKey: 0.1,
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 1.0,
                ])
        }

        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        #elseif canImport(AppKit)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
        #else
        return nil
        #endif
    }
}
#endif
