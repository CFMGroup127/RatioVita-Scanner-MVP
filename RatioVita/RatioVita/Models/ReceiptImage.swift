import CoreGraphics
import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class ReceiptImage {
    @Attribute(.unique) var id: UUID
    var pageIndex: Int
    var ocrText: String?
    var createdAt: Date
    
    // Stored as JPEG-encoded data for portability across platforms
    var imageData: Data
    
    // Parent relationship
    @Relationship var receipt: Receipt?
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        pageIndex: Int,
        image: RVImage,
        ocrText: String? = nil,
        createdAt: Date = .now,
        receipt: Receipt? = nil,
        compressionQuality: CGFloat = 0.9
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.ocrText = ocrText
        self.createdAt = createdAt
        imageData = ReceiptImage.encodeJPEG(image: image, quality: compressionQuality)
        self.receipt = receipt
    }

    /// Restore / import path when JPEG bytes are already persisted (Sovereign Master Archive round-trip).
    init(
        id: UUID,
        pageIndex: Int,
        jpegData: Data,
        ocrText: String?,
        createdAt: Date,
        receipt: Receipt?
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.ocrText = ocrText
        self.createdAt = createdAt
        imageData = jpegData
        self.receipt = receipt
    }
    
    // MARK: - Platform helpers
    
    var platformImage: RVImage? {
        ReceiptImage.decodeImage(from: imageData)
    }
    
    /// Re-encodes a full raster (e.g. after rotation or sharpen) and clears OCR until re-run.
    func replaceEncodedImage(_ image: RVImage, compressionQuality: CGFloat = 0.92) {
        imageData = ReceiptImage.encodeJPEG(image: image, quality: compressionQuality)
        ocrText = nil
    }

    /// Replace pixels **and** OCR together (region crop / rescan replace).
    func replaceRasterAndOCR(image: RVImage, ocrText: String?, compressionQuality: CGFloat = 0.92) {
        imageData = ReceiptImage.encodeJPEG(image: image, quality: compressionQuality)
        self.ocrText = ocrText
    }

    func applyRotationQuarterTurnsClockwise(_ delta: Int) {
        guard let plat = platformImage,
              let rotated = plat.rv_rotatedQuarterTurnsClockwise(delta) else { return }
        replaceEncodedImage(rotated)
    }

    func applyFlipHorizontal() {
        guard let plat = platformImage,
              let flipped = plat.rv_flippedHorizontally() else { return }
        replaceEncodedImage(flipped)
    }

    func applyFlipVertical() {
        guard let plat = platformImage,
              let flipped = plat.rv_flippedVertically() else { return }
        replaceEncodedImage(flipped)
    }

    /// Runs the same receipt enhancement pass used on import (sharpen + contrast).
    @MainActor
    func applyReceiptSharpening() async throws {
        guard let plat = platformImage else { return }
        let processed = try await ImageProcessing.processImage(plat, with: .receiptDefault)
        replaceEncodedImage(processed)
    }

    // MARK: - Encoding/Decoding

    static func encodeJPEG(image: RVImage, quality: CGFloat) -> Data {
        let prepared = ReceiptImageRasterOps.prepareForPersistence(image) ?? image
        #if canImport(UIKit)
        return prepared.jpegData(compressionQuality: quality) ?? Data()
        #elseif canImport(AppKit)
        guard let tiff = prepared.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else
        {
            return Data()
        }
        return jpeg
        #else
        return Data()
        #endif
    }
    
    private static func decodeImage(from data: Data) -> RVImage? {
        #if canImport(UIKit)
        RVImage.rv_decodedNormalizingEXIFOrientation(from: data)
        #elseif canImport(AppKit)
        return RVImage.rv_decodedNormalizingEXIFOrientation(from: data) ?? NSImage(data: data)
        #endif
    }
}
