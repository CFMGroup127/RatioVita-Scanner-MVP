import Testing
@testable import RatioVita

@Suite("ImageProcessing pipeline")
struct ImageProcessingTests {

    @Test("processImage returns an image (stub returns input)")
    func processImageReturnsImage() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 100, height: 100)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 100, height: 100)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        #else
        #skip("No image type available")
        #endif

        let result = try await ImageProcessing.processImage(img, with: .receiptDefault)
        #expect(result != nil, "processImage should return an image")
    }

    @Test("processImage with receiptDefault does not crash")
    func processImageReceiptDefault() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 40, height: 40)
        let img = UIGraphicsImageRenderer(size: size).image { _ in }
        #elseif canImport(AppKit)
        let size = NSSize(width: 40, height: 40)
        let img = NSImage(size: size)
        #else
        #skip("No image type available")
        #endif

        _ = try await ImageProcessing.processImage(img, with: .receiptDefault)
        // Stub returns same image; when real implementation adds compression,
        // we can add: lower quality produces smaller data.
    }
}
