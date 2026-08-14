//
//  DocumentBoundingBoxDetector.swift
//  RatioVita
//
//  On-device rectangle detection for live camera document framing.
//

import CoreGraphics
import Foundation
import Vision

#if os(iOS) || os(visionOS)

/// Runs `VNDetectRectanglesRequest` on video frames off the main thread.
final class DocumentBoundingBoxDetector: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.ratiovita.scanner.documentBounds", qos: .userInitiated)
    private var lastProcessedAt: CFAbsoluteTime = 0
    private let minInterval: CFAbsoluteTime = 1.0 / 12.0

    func detectRectangle(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right,
        completion: @escaping @Sendable (DocumentRectangleBounds?) -> Void
    ) {
        queue.async { [self] in
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastProcessedAt >= minInterval else { return }
            lastProcessedAt = now

            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = 0.8
            request.maximumObservations = 1
            request.quadratureTolerance = 30
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let best = (request.results as? [VNRectangleObservation])?
                .max(by: { $0.confidence < $1.confidence })
            let bounds = best.flatMap { DocumentRectangleBounds(observation: $0) }
            DispatchQueue.main.async {
                completion(bounds)
            }
        }
    }
}

#endif
