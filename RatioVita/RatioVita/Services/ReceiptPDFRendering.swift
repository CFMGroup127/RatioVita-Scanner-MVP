//
//  ReceiptPDFRendering.swift
//  RatioVita
//
//  Rasterizes PDF pages to bitmaps for Vision / Core Image (macOS + iOS).
//

import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReceiptPDFRendering {
    /// First PDF page as a bitmap (e.g. Zoho vault thumbnails). Uses a higher raster cap so 64×64 grids stay sharp.
    static func firstPageImage(fromDocumentAt url: URL, maxPixelDimension: CGFloat = 900) throws -> RVImage {
        guard let document = PDFDocument(url: url), document.pageCount > 0,
              let page = document.page(at: 0) else
        {
            throw ScannerError.invalidImage
        }
        return image(from: page, maxPixelDimension: maxPixelDimension)
    }

    /// Renders each page up to `maxPages` as an sRGB-ish bitmap suitable for OCR.
    static func images(fromDocumentAt url: URL, maxPages: Int = 25) throws -> [RVImage] {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw ScannerError.invalidImage
        }
        let limit = min(document.pageCount, max(1, maxPages))
        var images: [RVImage] = []
        images.reserveCapacity(limit)
        for index in 0..<limit {
            guard let page = document.page(at: index) else { continue }
            images.append(image(from: page))
        }
        guard !images.isEmpty else {
            throw ScannerError.invalidImage
        }
        return images
    }

    static func image(from page: PDFPage, maxPixelDimension: CGFloat = 1600) -> RVImage {
        let bounds = page.bounds(for: .mediaBox)
        let longest = max(bounds.width, bounds.height)
        let scale = min(maxPixelDimension / longest, 2.5)
        let pixelWidth = max(bounds.width * scale, 1)
        let pixelHeight = max(bounds.height * scale, 1)
        let target = CGSize(width: pixelWidth, height: pixelHeight)

        #if canImport(UIKit)
        // `thumbnail(of:for:)` bakes each page’s PDF rotation; manual CGContext flips can alternate wrong on some pages.
        let thumb = page.thumbnail(of: target, for: .mediaBox)
        if thumb.size.width >= 1, thumb.size.height >= 1 { return thumb }
        let size = target
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
        #elseif canImport(AppKit)
        let thumb = page.thumbnail(of: target, for: .mediaBox)
        if thumb.size.width >= 1, thumb.size.height >= 1 { return thumb }
        let size = target
        let pxWide = max(1, Int(ceil(size.width)))
        let pxHigh = max(1, Int(ceil(size.height)))
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
        ) else {
            return NSImage(size: NSSize(width: size.width, height: size.height))
        }
        rep.size = NSSize(width: size.width, height: size.height)
        guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: NSSize(width: size.width, height: size.height))
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        gctx.imageInterpolation = .high
        let ctx = gctx.cgContext
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(size.height))
        ctx.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: size.width, height: size.height))
        image.addRepresentation(rep)
        return image
        #else
        fatalError("PDF rendering unsupported on this platform")
        #endif
    }
}
