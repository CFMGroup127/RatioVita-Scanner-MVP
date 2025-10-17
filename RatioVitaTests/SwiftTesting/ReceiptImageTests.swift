import Testing
@testable import RatioVita

@Suite("ReceiptImage encoding/decoding")
struct ReceiptImageTests {
    @Test("JPEG encode/decode produces a non-nil platformImage")
    func jpegRoundTrip() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 40, height: 40)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 40, height: 40)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        #endif
        
        let receiptImage = ReceiptImage(pageIndex: 0, image: img, ocrText: nil)
        #expect(receiptImage.platformImage != nil, "platformImage should be decodable from stored JPEG data")
    }
}
