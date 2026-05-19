import CoreGraphics
import SwiftUI

#if canImport(UIKit)
import CoreImage
import ImageIO
import UIKit

typealias RVImage = UIImage
extension Image {
    init(rvImage: RVImage) { self.init(uiImage: rvImage) }
}

extension RVImage {
    /// Same strategy as macOS: ImageIO + Core Image bakes all EXIF orientations (including mirrored), then optional
    /// UIKit normalize.
    static func rv_decodedNormalizingEXIFOrientation(from data: Data) -> UIImage? {
        if let io = rv_decodedNormalizingEXIFOrientationViaImageIO(data) {
            return io.rv_normalizingImageOrientationIfNeeded()
        }
        guard let raw = UIImage(data: data) else { return nil }
        return raw.rv_normalizingImageOrientationIfNeeded()
    }

    private static func rv_orientationTag(fromImageSourceProperties props: [CFString: Any]?) -> Int32 {
        guard let props else { return 1 }
        if let n = props[kCGImagePropertyOrientation] as? NSNumber {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let n = exif[kCGImagePropertyOrientation] as? NSNumber
        {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let n = tiff[kCGImagePropertyTIFFOrientation] as? NSNumber
        {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        return 1
    }

    private static func rv_decodedNormalizingEXIFOrientationViaImageIO(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let exif = rv_orientationTag(fromImageSourceProperties: props)

        let oriented = CIImage(cgImage: cgImage).oriented(forExifOrientation: exif)
        let context = CIContext(options: nil)
        let extent = oriented.extent.integral
        guard extent.width > 1, extent.height > 1,
              let outputCG = context.createCGImage(oriented, from: extent) else { return nil }

        return UIImage(cgImage: outputCG, scale: 1, orientation: .up)
    }

    /// Quarter-turns clockwise (negative counts as counter‑clockwise).
    func rv_rotatedQuarterTurnsClockwise(_ quarters: Int) -> RVImage? {
        let q = ((quarters % 4) + 4) % 4
        guard q != 0 else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let newSize = q % 2 == 0 ? size : CGSize(width: size.height, height: size.width)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            c.rotate(by: CGFloat(q) * (.pi / 2))
            c.translateBy(x: -size.width / 2, y: -size.height / 2)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func rv_flippedHorizontally() -> RVImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: size.width, y: 0)
            c.scaleBy(x: -1, y: 1)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func rv_flippedVertically() -> RVImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: 0, y: size.height)
            c.scaleBy(x: 1, y: -1)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Bakes `imageOrientation` into upright `.up` pixels (same idea as `UIGraphicsBeginImageContext` + `draw`).
    func rv_normalizingImageOrientationIfNeeded() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#elseif canImport(AppKit)
import AppKit
import CoreImage
import ImageIO

typealias RVImage = NSImage
extension Image {
    init(rvImage: RVImage) { self.init(nsImage: rvImage) }
}

extension RVImage {
    /// Decodes image bytes and bakes orientation into upright pixels for Vision / Core Image.
    ///
    /// Uses ImageIO + Core Image first so all eight EXIF orientations (including mirrored tags 2, 4, 5, 7)
    /// are applied. Falls back to `NSImage` rasterization when ImageIO cannot decode the data.
    static func rv_decodedNormalizingEXIFOrientation(from data: Data) -> RVImage? {
        if let io = rv_decodedNormalizingEXIFOrientationViaImageIO(data) {
            return io
        }
        guard let raw = NSImage(data: data) else { return nil }
        return rv_rasterizeByDrawingNSImage(raw)
    }

    fileprivate static func rv_rasterizeByDrawingNSImage(_ image: NSImage) -> NSImage? {
        image.rv_rasterizeCopyApplyingDrawTransform { _ in }
    }

    /// Copies this image through a bitmap `NSGraphicsContext`, optionally adjusting `CGContext` before `draw`.
    /// Keeps flip/mirror math in the same coordinate space AppKit uses for `NSImage.draw`.
    fileprivate func rv_rasterizeCopyApplyingDrawTransform(_ preDraw: (CGContext) -> Void) -> NSImage? {
        let logic = size
        guard logic.width > 0.5, logic.height > 0.5 else { return nil }

        var pxWide = 0
        var pxHigh = 0
        for rep in representations {
            if let bmp = rep as? NSBitmapImageRep, bmp.pixelsWide > 0, bmp.pixelsHigh > 0 {
                pxWide = max(pxWide, bmp.pixelsWide)
                pxHigh = max(pxHigh, bmp.pixelsHigh)
            }
        }
        if pxWide < 2 || pxHigh < 2 {
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            pxWide = max(2, Int(ceil(logic.width * scale)))
            pxHigh = max(2, Int(ceil(logic.height * scale)))
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxWide,
            pixelsHigh: pxHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = logic

        guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        gctx.imageInterpolation = .high
        let ctx = gctx.cgContext
        ctx.saveGState()
        preDraw(ctx)
        draw(
            in: NSRect(origin: .zero, size: logic),
            from: NSRect(origin: .zero, size: logic),
            operation: .copy,
            fraction: 1.0
        )
        ctx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()

        let out = NSImage(size: logic)
        out.addRepresentation(rep)
        return out
    }

    private static func rv_orientationTag(fromImageSourceProperties props: [CFString: Any]?) -> Int32 {
        guard let props else { return 1 }
        if let n = props[kCGImagePropertyOrientation] as? NSNumber {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let n = exif[kCGImagePropertyOrientation] as? NSNumber
        {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let n = tiff[kCGImagePropertyTIFFOrientation] as? NSNumber
        {
            let v = n.uint32Value
            return (1...8).contains(v) ? Int32(v) : 1
        }
        return 1
    }

    private static func rv_decodedNormalizingEXIFOrientationViaImageIO(_ data: Data) -> RVImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let exif = rv_orientationTag(fromImageSourceProperties: props)

        let oriented = CIImage(cgImage: cgImage).oriented(forExifOrientation: exif)
        let context = CIContext(options: nil)
        let extent = oriented.extent.integral
        guard extent.width > 1, extent.height > 1,
              let outputCG = context.createCGImage(oriented, from: extent) else { return nil }

        let size = NSSize(width: outputCG.width, height: outputCG.height)
        let rep = NSBitmapImageRep(cgImage: outputCG)
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        return img
    }

    /// Quarter-turns clockwise (negative counts as counter‑clockwise).
    func rv_rotatedQuarterTurnsClockwise(_ quarters: Int) -> RVImage? {
        let q = ((quarters % 4) + 4) % 4
        guard q != 0 else { return self }
        guard let cgIn = rv_cgImageForVisionAnalysis ?? rvCGImage else { return nil }
        var ci = CIImage(cgImage: cgIn)
        for _ in 0..<q {
            let e = ci.extent
            let t = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: e.height, ty: 0)
            ci = ci.transformed(by: t)
        }
        let context = CIContext(options: nil)
        let extent = ci.extent.integral
        guard extent.width > 1, extent.height > 1,
              let outCG = context.createCGImage(ci, from: extent) else { return nil }
        let out = NSImage(size: NSSize(width: outCG.width, height: outCG.height))
        out.addRepresentation(NSBitmapImageRep(cgImage: outCG))
        return out
    }

    func rv_flippedHorizontally() -> NSImage? {
        let logic = size
        guard logic.width > 0.5, logic.height > 0.5 else { return nil }
        return rv_rasterizeCopyApplyingDrawTransform { ctx in
            ctx.translateBy(x: CGFloat(logic.width), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
    }

    func rv_flippedVertically() -> NSImage? {
        let logic = size
        guard logic.width > 0.5, logic.height > 0.5 else { return nil }
        return rv_rasterizeCopyApplyingDrawTransform { ctx in
            ctx.translateBy(x: 0, y: CGFloat(logic.height))
            ctx.scaleBy(x: 1, y: -1)
        }
    }
}
#endif

extension RVImage {
    /// Bitmap as used for drawing — do not use raw `UIImage.cgImage` for Vision/CI when orientation metadata applies.
    var rvCGImage: CGImage? {
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
        #elseif canImport(AppKit)
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        var proposal = NSRect(origin: .zero, size: NSSize(width: w, height: h))
        if let cg = cgImage(forProposedRect: &proposal, context: nil, hints: nil) {
            return cg
        }
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        return cg
        #else
        return nil
        #endif
    }

    /// Same as `rvCGImage` on iOS; on macOS prefers one raster pass so bitmap matches UI for Vision orientation probes.
    var rv_cgImageForVisionAnalysis: CGImage? {
        #if canImport(UIKit)
        rvCGImage
        #elseif canImport(AppKit)
        guard let baked = NSImage.rv_rasterizeByDrawingNSImage(self),
              let rep = baked.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              let cg = rep.cgImage else { return rvCGImage }
        return cg
        #else
        return nil
        #endif
    }
}
