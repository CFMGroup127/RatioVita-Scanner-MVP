//
//  VisionReceiptAnalysis.swift
//  RatioVita
//
//  Shared Vision pipeline for receipt OCR and rectangle detection (iOS + macOS).
//

import CoreGraphics
import Foundation
import Vision

enum VisionReceiptAnalysis {
    /// Runs text recognition (optional) and rectangle detection when OCR is enabled.
    static func analyzeReceipt(
        cgImage: CGImage,
        ocrEnabled: Bool,
        textRecognitionLevel: VNRequestTextRecognitionLevel
    ) throws -> (ocrText: String?, confidence: Double?, rectangles: [DetectedRectangle]) {
        guard ocrEnabled else {
            return (nil, nil, [])
        }

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = textRecognitionLevel
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLanguages = ["en-US"]

        let textHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try textHandler.perform([textRequest])

        guard let textResults = textRequest.results else {
            throw ScannerError.ocrFailed
        }

        let recognizedStrings = textResults.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let ocrText = recognizedStrings.joined(separator: "\n")

        let confidences = textResults.compactMap { observation in
            observation.topCandidates(1).first?.confidence
        }
        let avgConfidence = confidences.isEmpty ? 0.0 : Double(confidences.reduce(0.0, +)) / Double(confidences.count)

        let rectangles = try detectRectangles(cgImage: cgImage)
        return (ocrText, avgConfidence, rectangles)
    }

    private static func detectRectangles(cgImage: CGImage) throws -> [DetectedRectangle] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.map { observation in
            DetectedRectangle(
                boundingBox: observation.boundingBox,
                confidence: Double(observation.confidence),
                corners: [
                    observation.topLeft,
                    observation.topRight,
                    observation.bottomRight,
                    observation.bottomLeft,
                ]
            )
        }.sorted { $0.confidence > $1.confidence }
    }
}
