import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PreviewScannerError: Error {
    case failed
}

final class PreviewScannerService: ScannerService {
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // Simulate a short delay like a real scan
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let demoImage = Self.placeholderImage()
        let ocr = ocrEnabled ? "ACME MARKET\nDate: \(Date())\nTotal: 42.39\nItems: Apples, Bread, Milk" : nil
        
        // Create extracted data
        let extractedData = ExtractedData(
            merchant: "ACME Market",
            total: Decimal(string: "42.39") ?? 42.39,
            currency: Locale.current.currency?.identifier ?? "USD",
            date: Date(),
            merchantConfidence: 0.95,
            totalConfidence: 0.98,
            dateConfidence: 0.90
        )
        
        // Create processing metadata
        let processingSteps = [
            ImageProcessingStep(name: "Capture", description: "Image captured", duration: 0.1),
            ImageProcessingStep(name: "OCR", description: "Text recognition", duration: 0.5),
            ImageProcessingStep(name: "Parsing", description: "Data extraction", duration: 0.2),
        ]
        
        let metadata = ProcessingMetadata(
            processingTime: 0.8,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: compressionEnabled ? 0.6 : 0.9,
            imageProcessingSteps: processingSteps
        )
        
        // Create scanned page
        let page = ScannedPage(
            image: demoImage,
            originalImage: demoImage,
            pageNumber: 1,
            ocrText: ocr,
            confidence: ocrEnabled ? 0.85 : nil,
            capturedAt: Date()
        )
        
        return ScanResult(
            scannedPages: [page],
            extractedData: extractedData,
            processingMetadata: metadata
        )
    }
    
    // MARK: - Phase 2 optional hooks (no-ops for preview)

    func requestCameraPermission() async -> Bool { true }
    func isCameraAvailable() -> Bool { true }
    func getCameraPermissionStatus() -> CameraPermissionStatus { .authorized }
    func getVideoPreviewLayer() -> Any? { nil }
    func switchCamera() {}
    func focusCamera(at _: CGPoint) {}
    
    // MARK: - Cross-platform placeholder
    
    private static func placeholderImage() -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let text = "Receipt Preview"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 30, width: size.width, height: 60)
            text.draw(in: rect, withAttributes: attrs)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 800, height: 1200)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let text = "Receipt Preview" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 30, width: size.width, height: 60)
        text.draw(in: rect, withAttributes: attrs)
        
        return image
        #endif
    }
}
