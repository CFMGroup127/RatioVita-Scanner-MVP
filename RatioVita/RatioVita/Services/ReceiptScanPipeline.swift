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
        compressionEnabled: Bool,
        captureLedgerContext: SovereignLedger? = nil
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
            processingMetadata: processingMetadata,
            captureLedgerContextRaw: captureLedgerContext?.rawValue
        )
    }

    /// Processes one or more imported/captured still images through enhancement + Vision OCR, then merges extraction.
    /// Used by live multi-page camera **Done** and photo batch imports.
    static func processImportedImages(
        images: [RVImage],
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        captureLedgerContext: SovereignLedger? = nil
    ) async throws -> ScanResult {
        guard !images.isEmpty else { throw ScannerError.invalidImage }
        if images.count == 1 {
            return try await processImported(
                image: images[0],
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled,
                captureLedgerContext: captureLedgerContext
            )
        }

        var scannedPages: [ScannedPage] = []
        for (idx, original) in images.enumerated() {
            let page = try await processImportedPageRaster(
                original,
                pageNumber: idx + 1,
                ocrEnabled: ocrEnabled
            )
            scannedPages.append(page)
        }

        return mergedScanResult(
            fromPages: scannedPages,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            captureLedgerContext: captureLedgerContext
        )
    }

    /// Live camera **Finish Scan**: load each temp JPEG one at a time so multi-page batches stay off the heap.
    static func processImportedImageURLs(
        urls: [URL],
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        captureLedgerContext: SovereignLedger? = nil
    ) async throws -> ScanResult {
        guard !urls.isEmpty else { throw ScannerError.invalidImage }
        if urls.count == 1 {
            let image = try loadRaster(from: urls[0])
            return try await processImported(
                image: image,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled,
                captureLedgerContext: captureLedgerContext
            )
        }

        var scannedPages: [ScannedPage] = []
        for (idx, url) in urls.enumerated() {
            let page = try await processPageFromDiskURL(url, pageNumber: idx + 1, ocrEnabled: ocrEnabled)
            scannedPages.append(page)
        }

        return mergedScanResult(
            fromPages: scannedPages,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            captureLedgerContext: captureLedgerContext
        )
    }

    private static func processPageFromDiskURL(
        _ url: URL,
        pageNumber: Int,
        ocrEnabled: Bool
    ) async throws -> ScannedPage {
        let raster = try autoreleasepool {
            try loadRaster(from: url)
        }
        return try await processImportedPageRaster(
            raster,
            pageNumber: pageNumber,
            ocrEnabled: ocrEnabled
        )
    }

    private static func loadRaster(from url: URL) throws -> RVImage {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw ScannerError.invalidImage }
        #if canImport(UIKit)
        guard let image = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
            throw ScannerError.invalidImage
        }
        return image
        #elseif canImport(AppKit)
        guard let image = RVImage.rv_decodedNormalizingEXIFOrientation(from: data) ?? NSImage(data: data) else {
            throw ScannerError.invalidImage
        }
        return image
        #else
        throw ScannerError.invalidImage
        #endif
    }

    private static func processImportedPageRaster(
        _ original: RVImage,
        pageNumber: Int,
        ocrEnabled: Bool
    ) async throws -> ScannedPage {
        let normalized = ReceiptImageRasterOps.prepareForPersistence(original) ?? original
        let oriented = VisionReceiptOrientation.autoCorrectReceiptOrientation(
            image: normalized,
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
        return ScannedPage(
            image: processed,
            originalImage: oriented,
            pageNumber: pageNumber,
            ocrText: ocrText,
            confidence: confidence,
            detectedRectangles: detectedRectangles.isEmpty ? nil : detectedRectangles,
            capturedAt: Date()
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
        compressionEnabled: Bool,
        captureLedgerContext: SovereignLedger? = nil
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
            processingMetadata: processingMetadata,
            captureLedgerContextRaw: captureLedgerContext?.rawValue
        )
    }

    /// When OCR / merged extraction yields a **document transaction date**, callers should use it as the receipt’s
    /// primary timeline (`Receipt.createdAt`) so lists and sorts match the printed receipt date. Otherwise use capture
    /// / import time.
    static func preferredReceiptCreatedAt(extractedDocumentDate: Date?, captureOrImportFallback: Date) -> Date {
        extractedDocumentDate ?? captureOrImportFallback
    }
}
