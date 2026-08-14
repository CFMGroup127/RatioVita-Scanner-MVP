//
//  DocumentRectangleBounds.swift
//  RatioVita
//
//  Sendable snapshot of a Vision rectangle for UI overlay and perspective correction.
//

import CoreGraphics
import Foundation
import Vision

/// Normalized document corners from Vision (origin bottom-left, 0…1).
struct DocumentRectangleBounds: Sendable, Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
    let confidence: Float

    init(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint,
        confidence: Float
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
        self.confidence = confidence
    }

    init?(observation: VNRectangleObservation) {
        guard observation.confidence >= 0.55 else { return nil }
        topLeft = observation.topLeft
        topRight = observation.topRight
        bottomRight = observation.bottomRight
        bottomLeft = observation.bottomLeft
        confidence = observation.confidence
    }
}
