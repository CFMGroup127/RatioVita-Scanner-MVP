//
//  LiveMultiPageCaptureImagePrep.swift
//  RatioVita
//
//  Caps in-memory live-scan pages — avoids holding 12MP buffers in MultiPageScanBuffer.
//

import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum LiveMultiPageCaptureImagePrep {
    /// Long-edge cap for pages held during a live session (OCR runs again at pipeline submit).
    static let sessionBufferMaxLongEdge: CGFloat = 2048

    /// Long-edge cap for strip thumbnails (display only).
    static let stripThumbnailMaxLongEdge: CGFloat = 160

    /// Downsamples if needed; safe to call repeatedly on already-normalized images.
    static func normalizedForSessionBuffer(_ image: RVImage) -> RVImage {
        autoreleasepool {
            downsample(image, maxLongEdge: sessionBufferMaxLongEdge) ?? image
        }
    }

    static func stripThumbnail(from image: RVImage) -> RVImage {
        autoreleasepool {
            downsample(image, maxLongEdge: stripThumbnailMaxLongEdge) ?? image
        }
    }

    private static func downsample(_ image: RVImage, maxLongEdge: CGFloat) -> RVImage? {
        guard maxLongEdge > 0 else { return nil }
        #if canImport(UIKit)
        return downsampleUIImage(image, maxLongEdge: maxLongEdge)
        #elseif canImport(AppKit)
        return downsampleNSImage(image, maxLongEdge: maxLongEdge)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private static func downsampleUIImage(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage? {
        guard let cg = image.rv_cgImageForVisionAnalysis ?? image.cgImage else { return nil }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let long = max(width, height)
        guard long > maxLongEdge + 0.5 else { return image }

        let scale = maxLongEdge / long
        let newSize = CGSize(width: (width * scale).rounded(.down), height: (height * scale).rounded(.down))
        guard newSize.width >= 1, newSize.height >= 1 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            ctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    #if canImport(AppKit)
    private static func downsampleNSImage(_ image: NSImage, maxLongEdge: CGFloat) -> NSImage? {
        guard let cg = image.rv_cgImageForVisionAnalysis ?? image.rvCGImage else { return nil }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let long = max(width, height)
        guard long > maxLongEdge + 0.5 else { return image }

        let scale = maxLongEdge / long
        let newW = Int((width * scale).rounded(.down))
        let newH = Int((height * scale).rounded(.down))
        guard newW >= 1, newH >= 1 else { return nil }

        let colorSpace = cg.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: newW,
                height: newH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        guard let scaled = context.makeImage() else { return nil }

        let size = NSSize(width: newW, height: newH)
        let rep = NSBitmapImageRep(cgImage: scaled)
        let out = NSImage(size: size)
        out.addRepresentation(rep)
        return out
    }
    #endif
}
