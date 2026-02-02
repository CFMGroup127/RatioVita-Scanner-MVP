//
//  ProcessingMetadata.swift
//  RatioVita
//
//  SovereignHash, duration, and pipeline steps for audit.
//

import Foundation

struct ProcessingMetadata {
    let processingTime: TimeInterval
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    let compressionQuality: Double
    let imageProcessingSteps: [ImageProcessingStep]
    let errors: [ProcessingError]?

    init(
        processingTime: TimeInterval,
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        compressionQuality: Double,
        imageProcessingSteps: [ImageProcessingStep],
        errors: [ProcessingError]? = nil
    ) {
        self.processingTime = processingTime
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.compressionQuality = compressionQuality
        self.imageProcessingSteps = imageProcessingSteps
        self.errors = errors
    }

    var hasErrors: Bool {
        errors != nil && !(errors!.isEmpty)
    }

    var processingStepsDescription: String {
        imageProcessingSteps.map(\.description).joined(separator: ", ")
    }
}
