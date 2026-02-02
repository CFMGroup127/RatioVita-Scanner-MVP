//
//  ScanResult.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents the result of a scanning operation
struct ScanResult {
    let id: UUID
    let scannedPages: [ScannedPage]
    let extractedData: ExtractedData
    let processingMetadata: ProcessingMetadata
    let createdAt: Date
    
    init(
        scannedPages: [ScannedPage],
        extractedData: ExtractedData,
        processingMetadata: ProcessingMetadata
    ) {
        self.id = UUID()
        self.scannedPages = scannedPages
        self.extractedData = extractedData
        self.processingMetadata = processingMetadata
        self.createdAt = Date()
    }
    
    // Computed properties
    var hasMultiplePages: Bool {
        scannedPages.count > 1
    }
    
    var totalPages: Int {
        scannedPages.count
    }
    
    var primaryPage: ScannedPage? {
        scannedPages.first
    }
    
    var allImages: [RVImage] {
        scannedPages.compactMap { $0.image }
    }
    
    var allOCRText: [String] {
        scannedPages.compactMap { $0.ocrText }
    }
    
    var combinedOCRText: String {
        allOCRText.joined(separator: "\n\n")
    }
    
    var averageConfidence: Double {
        let confidences = scannedPages.compactMap { $0.confidence }
        guard !confidences.isEmpty else { return 0.0 }
        return confidences.reduce(0, +) / Double(confidences.count)
    }
}

/// Represents a line item from a receipt
struct LineItem {
    let description: String
    let quantity: Int?
    let unitPrice: Decimal?
    let totalPrice: Decimal?
    let confidence: Double?
    
    init(
        description: String,
        quantity: Int? = nil,
        unitPrice: Decimal? = nil,
        totalPrice: Decimal? = nil,
        confidence: Double? = nil
    ) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.confidence = confidence
    }
}

/// Represents an error during processing
struct ProcessingError {
    let code: String
    let message: String
    let step: String
    let recoverable: Bool
    
    init(code: String, message: String, step: String, recoverable: Bool = true) {
        self.code = code
        self.message = message
        self.step = step
        self.recoverable = recoverable
    }
}
