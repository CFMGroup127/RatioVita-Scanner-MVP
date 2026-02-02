//
//  DetectedRectangle.swift
//  RatioVita
//
//  Vision wrapper for document/receipt rectangle detection (VNRectangleObservation).
//

import Foundation
import CoreGraphics

struct DetectedRectangle: Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Double
    let corners: [CGPoint]

    init(boundingBox: CGRect, confidence: Double, corners: [CGPoint]) {
        self.id = UUID()
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.corners = corners
    }

    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }

    var aspectRatio: CGFloat {
        guard boundingBox.height > 0 else { return 0 }
        return boundingBox.width / boundingBox.height
    }

    var isReasonableSize: Bool {
        area > 1000 && aspectRatio > 0.5 && aspectRatio < 2.0
    }
}
