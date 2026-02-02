//
//  ImageProcessingStep.swift
//  RatioVita
//
//  Single step in the Sovereign filter pipeline (capture, enhance, OCR).
//

import Foundation

struct ImageProcessingStep {
    let name: String
    let description: String
    let duration: TimeInterval
    let success: Bool

    init(name: String, description: String, duration: TimeInterval, success: Bool = true) {
        self.name = name
        self.description = description
        self.duration = duration
        self.success = success
    }
}
