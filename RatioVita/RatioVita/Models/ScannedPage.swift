//
//  ScannedPage.swift
//  RatioVita
//
//  Multi-page receipt container: image, OCR text, confidence, detected rects.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ScannedPage {
    let id: UUID
    let image: RVImage
    let originalImage: RVImage
    let pageNumber: Int
    let ocrText: String?
    let confidence: Double?
    let detectedRectangles: [DetectedRectangle]?
    let processingNotes: String?

    init(
        image: RVImage,
        originalImage: RVImage,
        pageNumber: Int = 1,
        ocrText: String? = nil,
        confidence: Double? = nil,
        detectedRectangles: [DetectedRectangle]? = nil,
        processingNotes: String? = nil
    ) {
        self.id = UUID()
        self.image = image
        self.originalImage = originalImage
        self.pageNumber = pageNumber
        self.ocrText = ocrText
        self.confidence = confidence
        self.detectedRectangles = detectedRectangles
        self.processingNotes = processingNotes
    }

    var hasOCRResults: Bool {
        ocrText != nil && confidence != nil
    }

    var hasDetectedRectangles: Bool {
        guard let r = detectedRectangles else { return false }
        return !r.isEmpty
    }

    var primaryRectangle: DetectedRectangle? {
        detectedRectangles?.first
    }
}
