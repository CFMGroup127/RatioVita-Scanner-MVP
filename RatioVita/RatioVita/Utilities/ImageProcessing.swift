//
//  ImageProcessing.swift
//  RatioVita
//
//  Sovereign receipt enhancement: sharpen + contrast via Core Image (iOS + macOS).
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ImageProcessingError: Error {
    case couldNotCreateCIImage
    case couldNotRender
}

enum ImageProcessing {
    private static let ciContext = CIContext()

    /// Applies receipt-oriented sharpening and contrast for clearer OCR edges.
    static func processImage(_ image: RVImage, with options: ProcessingOptions) async throws -> RVImage {
        switch options {
            case .receiptDefault:
                try await applyReceiptEnhancement(to: image)
        }
    }

    private static func applyReceiptEnhancement(to image: RVImage) async throws -> RVImage {
        guard let input = ciImage(from: image) else {
            throw ImageProcessingError.couldNotCreateCIImage
        }

        let output = Self.filterChain(input: input)

        guard let cgImage = ciContext.createCGImage(output, from: output.extent.integral) else {
            throw ImageProcessingError.couldNotRender
        }

        return makeRVImage(cgImage: cgImage, reference: image)
    }

    private static func filterChain(input: CIImage) -> CIImage {
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = input
        sharpen.sharpness = 0.62

        let color = CIFilter.colorControls()
        color.inputImage = sharpen.outputImage ?? input
        color.contrast = 1.18
        color.saturation = 0.92
        color.brightness = 0.02

        return color.outputImage ?? input
    }

    private static func ciImage(from image: RVImage) -> CIImage? {
        #if canImport(UIKit)
        guard let cg = image.rv_cgImageForVisionAnalysis ?? image.rvCGImage else { return nil }
        return CIImage(cgImage: cg)
        #elseif canImport(AppKit)
        guard let cg = image.rv_cgImageForVisionAnalysis ?? image.rvCGImage else { return nil }
        return CIImage(cgImage: cg)
        #else
        return nil
        #endif
    }

    private static func makeRVImage(cgImage: CGImage, reference: RVImage) -> RVImage {
        #if canImport(UIKit)
        UIImage(cgImage: cgImage, scale: reference.scale, orientation: .up)
        #elseif canImport(AppKit)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        return img
        #endif
    }
}
