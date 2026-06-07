import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Axis-aligned crop and import normalization shared by **Region crop**, **Replace page**, and ingest.
enum ReceiptImageRasterOps {
    /// Longest edge cap for receipt persistence (memory + SwiftData size).
    static let importMaxLongEdge: CGFloat = 2048

    /// Downscales and rasterizes to an **opaque** bitmap before JPEG encode (avoids alpha-channel memory doubling).
    static func prepareForPersistence(_ image: RVImage, maxLongEdge: CGFloat = importMaxLongEdge) -> RVImage? {
        guard let source = image.rvCGImage else { return nil }
        let prepared = downscaleOpaqueCGImage(source, maxLongEdge: maxLongEdge) ?? source
        #if canImport(UIKit)
        return UIImage(cgImage: prepared, scale: 1, orientation: .up) as RVImage
        #elseif canImport(AppKit)
        return NSImage(cgImage: prepared, size: NSSize(width: prepared.width, height: prepared.height)) as RVImage
        #else
        return nil
        #endif
    }

    /// `rect` is normalized in **top-left** origin (0…1) over the full raster.
    static func cropTopLeftNormalized(_ image: RVImage, rect: CGRect) -> RVImage? {
        guard let cgFull = image.rvCGImage else { return nil }
        guard let cropped = cropCore(cg: cgFull, rect: rect) else { return nil }
        #if canImport(UIKit)
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up) as RVImage
        #elseif canImport(AppKit)
        let sz = NSSize(width: cropped.width, height: cropped.height)
        return NSImage(cgImage: cropped, size: sz) as RVImage
        #else
        return nil
        #endif
    }

    private static func cropCore(cg: CGImage, rect: CGRect) -> CGImage? {
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let r = CGRect(
            x: rect.minX * w,
            y: rect.minY * h,
            width: rect.width * w,
            height: rect.height * h
        ).integral
        guard r.width >= 8, r.height >= 8 else { return nil }
        return cg.cropping(to: r)
    }

    private static func downscaleOpaqueCGImage(_ source: CGImage, maxLongEdge: CGFloat) -> CGImage? {
        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        guard width > 0, height > 0 else { return nil }

        let longEdge = max(width, height)
        let scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1
        let targetW = max(1, Int((width * scale).rounded(.down)))
        let targetH = max(1, Int((height * scale).rounded(.down)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetW,
            height: targetH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        return context.makeImage()
    }
}
