//
//  ImagePerspectiveCorrector.swift
//  RatioVita
//
//  Flattens angled document photos using Core Image perspective correction.
//

import CoreGraphics
import CoreImage
import Foundation
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ImagePerspectiveCorrector {
    /// Warps `image` to a flat rectangle using Vision corner points.
    static func correctPerspective(of image: RVImage, observation: VNRectangleObservation) -> RVImage? {
        correctPerspective(
            of: image,
            bounds: DocumentRectangleBounds(
                topLeft: observation.topLeft,
                topRight: observation.topRight,
                bottomRight: observation.bottomRight,
                bottomLeft: observation.bottomLeft,
                confidence: observation.confidence
            )
        )
    }

    static func correctPerspective(of image: RVImage, bounds: DocumentRectangleBounds) -> RVImage? {
        #if canImport(UIKit)
        guard let uiImage = image as? UIImage, let ciImage = CIImage(image: uiImage) else { return nil }
        #elseif canImport(AppKit)
        guard let nsImage = image as? NSImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cg)
        #else
        return nil
        #endif

        let imageSize = ciImage.extent.size
        guard imageSize.width > 1, imageSize.height > 1 else { return nil }

        let topLeft = vector(for: bounds.topLeft, imageSize: imageSize)
        let topRight = vector(for: bounds.topRight, imageSize: imageSize)
        let bottomRight = vector(for: bounds.bottomRight, imageSize: imageSize)
        let bottomLeft = vector(for: bounds.bottomLeft, imageSize: imageSize)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(topLeft, forKey: "inputTopLeft")
        filter.setValue(topRight, forKey: "inputTopRight")
        filter.setValue(bottomRight, forKey: "inputBottomRight")
        filter.setValue(bottomLeft, forKey: "inputBottomLeft")

        guard let outputImage = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        let extent = outputImage.extent.integral
        guard extent.width > 1, extent.height > 1,
              let cgImage = context.createCGImage(outputImage, from: extent) else { return nil }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .up)
        #elseif canImport(AppKit)
        let size = NSSize(width: extent.width, height: extent.height)
        let out = NSImage(size: size)
        out.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return out
        #else
        return nil
        #endif
    }

    private static func vector(for normalizedPoint: CGPoint, imageSize: CGSize) -> CIVector {
        let x = normalizedPoint.x * imageSize.width
        let y = (1 - normalizedPoint.y) * imageSize.height
        return CIVector(cgPoint: CGPoint(x: x, y: y))
    }
}
