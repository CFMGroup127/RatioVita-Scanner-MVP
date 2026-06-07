//
//  ReceiptScanPipeline.swift
//  RatioVita
//
//  File import / shared path: enhance image, optional Vision OCR, build ScanResult.
//

import Foundation
import PDFKit
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReceiptScanPipeline {
    /// Maximum PDF pages to rasterize per import (memory / latency guard).
    private static let maxImportedPDFPages = 25

    /// Processes an already-loaded receipt image (e.g. macOS file import or photo pick).
    static func processImported(
        image: RVImage,
        ocrEnabled: Bool,
        compressionEnabled: Bool
    ) async throws -> ScanResult {
        let normalized = ReceiptImageRasterOps.prepareForPersistence(image) ?? image
        let oriented = VisionReceiptOrientation.autoCorrectReceiptOrientation(image: normalized, ocrEnabled: ocrEnabled)
        let processed = try await ImageProcessing.processImage(oriented, with: .receiptDefault)

        guard let cgImage = processed.rv_cgImageForVisionAnalysis ?? processed.rvCGImage else {
            throw ScannerError.invalidImage
        }

        let level: VNRequestTextRecognitionLevel = .accurate
        let (ocrText, confidence, detectedRectangles) = try VisionReceiptAnalysis.analyzeReceipt(
            cgImage: cgImage,
            ocrEnabled: ocrEnabled,
            textRecognitionLevel: level
        )

        let scannedPage = ScannedPage(
            image: processed,
            originalImage: oriented,
            pageNumber: 1,
            ocrText: ocrText,
            confidence: confidence,
            detectedRectangles: detectedRectangles.isEmpty ? nil : detectedRectangles,
            capturedAt: Date()
        )

        let extractedData: ExtractedData = if ocrEnabled, let text = ocrText, !text.isEmpty {
            OCRParsing.extractData(from: text)
        } else {
            ExtractedData()
        }

        let processingSteps = [
            ImageProcessingStep(name: "Image Import", description: "Loaded receipt image", duration: 0.1),
            ImageProcessingStep(
                name: "Sovereign Enhancement",
                description: "Sharpen + contrast (Core Image)",
                duration: 0.35
            ),
            ImageProcessingStep(
                name: "OCR Processing",
                description: "Vision text recognition",
                duration: ocrEnabled ? 0.9 : 0.0
            ),
        ]

        let processingMetadata = ProcessingMetadata(
            processingTime: 1.4,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: compressionEnabled ? 0.6 : 0.9,
            imageProcessingSteps: processingSteps
        )

        return ScanResult(
            scannedPages: [scannedPage],
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }

    /// Multi-page PDF: rasterize each page, run enhancement + Vision OCR, merge text for `OCRParsing`.
    static func processImportedPDF(
        at url: URL,
        ocrEnabled: Bool,
        compressionEnabled: Bool
    ) async throws -> ScanResult {
        let originals = try ReceiptPDFRendering.images(fromDocumentAt: url, maxPages: maxImportedPDFPages)
        var scannedPages: [ScannedPage] = []
        var combinedOCR = ""

        for (idx, original) in originals.enumerated() {
            let oriented = VisionReceiptOrientation.autoCorrectReceiptOrientation(
                image: original,
                ocrEnabled: ocrEnabled
            )
            let processed = try await ImageProcessing.processImage(oriented, with: .receiptDefault)
            guard let cgImage = processed.rv_cgImageForVisionAnalysis ?? processed.rvCGImage else {
                throw ScannerError.invalidImage
            }
            let level: VNRequestTextRecognitionLevel = .accurate
            let (ocrText, confidence, detectedRectangles) = try VisionReceiptAnalysis.analyzeReceipt(
                cgImage: cgImage,
                ocrEnabled: ocrEnabled,
                textRecognitionLevel: level
            )
            let page = ScannedPage(
                image: processed,
                originalImage: oriented,
                pageNumber: idx + 1,
                ocrText: ocrText,
                confidence: confidence,
                detectedRectangles: detectedRectangles.isEmpty ? nil : detectedRectangles,
                capturedAt: Date()
            )
            scannedPages.append(page)
            if let t = ocrText, !t.isEmpty {
                if !combinedOCR.isEmpty { combinedOCR += "\n\n" }
                combinedOCR += t
            }
        }

        let extractedData: ExtractedData = if ocrEnabled, !combinedOCR.isEmpty {
            OCRParsing.extractData(from: combinedOCR)
        } else {
            ExtractedData()
        }

        let processingSteps = [
            ImageProcessingStep(
                name: "PDF Import",
                description: "Loaded \(scannedPages.count) page(s)",
                duration: 0.15
            ),
            ImageProcessingStep(
                name: "Sovereign Enhancement",
                description: "Sharpen + contrast per page",
                duration: 0.35 * Double(scannedPages.count)
            ),
            ImageProcessingStep(
                name: "OCR Processing",
                description: "Vision text recognition per page",
                duration: ocrEnabled ? 0.85 * Double(scannedPages.count) : 0.0
            ),
        ]

        let processingMetadata = ProcessingMetadata(
            processingTime: 1.2 * Double(scannedPages.count),
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: compressionEnabled ? 0.6 : 0.9,
            imageProcessingSteps: processingSteps
        )

        return ScanResult(
            scannedPages: scannedPages,
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }

    /// Builds one `ScanResult` from multiple pages (e.g. camera “add page” or several imports merged before save).
    static func mergedScanResult(
        fromPages pages: [ScannedPage],
        ocrEnabled: Bool,
        compressionEnabled: Bool
    ) -> ScanResult {
        let renumbered = pages.enumerated().map { idx, page in
            ScannedPage(
                image: page.image,
                originalImage: page.originalImage,
                pageNumber: idx + 1,
                ocrText: page.ocrText,
                confidence: page.confidence,
                detectedRectangles: page.detectedRectangles,
                processingNotes: page.processingNotes,
                capturedAt: page.capturedAt
            )
        }

        let combinedOCR = renumbered
            .compactMap(\.ocrText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let extractedData: ExtractedData = if ocrEnabled, !combinedOCR.isEmpty {
            OCRParsing.extractData(from: combinedOCR)
        } else {
            ExtractedData()
        }

        let processingSteps = [
            ImageProcessingStep(
                name: "Merged receipt",
                description: "Combined \(renumbered.count) page(s) before save",
                duration: 0.05
            ),
        ]
        let processingMetadata = ProcessingMetadata(
            processingTime: 0.05,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: compressionEnabled ? 0.6 : 0.9,
            imageProcessingSteps: processingSteps
        )

        return ScanResult(
            scannedPages: renumbered,
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }

    /// When OCR / merged extraction yields a **document transaction date**, callers should use it as the receipt’s
    /// primary timeline (`Receipt.createdAt`) so lists and sorts match the printed receipt date. Otherwise use capture
    /// / import time.
    static func preferredReceiptCreatedAt(extractedDocumentDate: Date?, captureOrImportFallback: Date) -> Date {
        extractedDocumentDate ?? captureOrImportFallback
    }
}
