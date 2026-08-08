//
//  ReceiptBatchCaptureDiskCache.swift
//  RatioVita
//
//  Writes live-scan pages to temp JPEG files immediately after capture so heap stays small.
//

import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReceiptBatchCaptureDiskCache {
    /// Session page JPEG quality (balance size vs OCR legibility).
    static let pageJPEGQuality: CGFloat = 0.7

    /// Thumbnail strip quality — display only.
    static let thumbnailJPEGQuality: CGFloat = 0.55

    static func createSessionDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RatioVitaScan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Downsample → JPEG page file + small thumb file. Runs inside caller's autoreleasepool when possible.
    static func writePageFiles(
        from image: RVImage,
        sessionDirectory: URL,
        pageIndex: Int
    ) throws -> (pageURL: URL, thumbnailURL: URL) {
        let normalized = LiveMultiPageCaptureImagePrep.normalizedForSessionBuffer(image)
        let thumbRaster = LiveMultiPageCaptureImagePrep.stripThumbnail(from: normalized)

        let pageURL = sessionDirectory.appendingPathComponent(
            String(format: "page-%03d-%@.jpg", pageIndex, UUID().uuidString),
            isDirectory: false
        )
        let thumbURL = sessionDirectory.appendingPathComponent(
            String(format: "thumb-%03d-%@.jpg", pageIndex, UUID().uuidString),
            isDirectory: false
        )

        let pageData = encodeJPEG(normalized, quality: pageJPEGQuality)
        guard !pageData.isEmpty else { throw ReceiptBatchCaptureError.emptyJPEGData }
        try pageData.write(to: pageURL, options: .atomic)

        let thumbData = encodeJPEG(thumbRaster, quality: thumbnailJPEGQuality)
        if !thumbData.isEmpty {
            try thumbData.write(to: thumbURL, options: .atomic)
        } else {
            try pageData.write(to: thumbURL, options: .atomic)
        }

        return (pageURL, thumbURL)
    }

    static func deleteSessionDirectory(_ directory: URL?) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    private static func encodeJPEG(_ image: RVImage, quality: CGFloat) -> Data {
        #if canImport(UIKit)
        image.jpegData(compressionQuality: quality) ?? Data()
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
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
}

enum ReceiptBatchCaptureError: LocalizedError {
    case emptyJPEGData
    case noActiveSession

    var errorDescription: String? {
        switch self {
            case .emptyJPEGData:
                "Could not compress the captured page."
            case .noActiveSession:
                "Scan session is not active."
        }
    }
}
