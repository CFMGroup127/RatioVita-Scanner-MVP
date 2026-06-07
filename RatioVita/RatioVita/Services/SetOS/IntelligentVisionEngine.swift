import AVFoundation
import CoreImage
import Foundation
import Vision

enum DocumentAlignmentPhase: String, Sendable {
    case searching
    case tracking
    case aligning
    case ready
}

struct DetectedDocumentBounds: Identifiable, Sendable {
    let id: UUID
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let confidence: Float
    let alignmentScore: Double

    init(
        id: UUID = UUID(),
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        confidence: Float,
        alignmentScore: Double
    ) {
        self.id = id
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.confidence = confidence
        self.alignmentScore = alignmentScore
    }
}

/// Frame-by-frame rectangle detection + stability scoring (Sprint ZZZ).
final class IntelligentVisionEngine: @unchecked Sendable {
    private let sequenceHandler = VNSequenceRequestHandler()
    private let visionQueue = DispatchQueue(label: "com.ratiovita.intelligent.vision", qos: .userInitiated)
    private var stableFrameCount = 0
    private var lastSignature: [CGFloat] = []
    private var textLegibilityScore: Double = 0
    private var framesSinceTextProbe = 0

    var onBoundsUpdate: ((DetectedDocumentBounds?, DocumentAlignmentPhase, Bool) -> Void)?

    nonisolated func reset() {
        visionQueue.async {
            self.stableFrameCount = 0
            self.lastSignature = []
            self.textLegibilityScore = 0
            self.framesSinceTextProbe = 0
        }
    }

    nonisolated func process(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        // `sync` uses a non-escaping, non-Sendable closure, so the buffer is never sent across
        // an isolation boundary; work is still serialized on the vision queue (Swift 6 safe).
        visionQueue.sync {
            analyze(sampleBuffer: sampleBuffer, orientation: orientation)
        }
    }

    private func analyze(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumConfidence = 0.55
        rectangleRequest.minimumAspectRatio = 0.25
        rectangleRequest.maximumAspectRatio = 1.0
        rectangleRequest.quadratureTolerance = 18

        do {
            try sequenceHandler.perform([rectangleRequest], on: pixelBuffer, orientation: orientation)
        } catch {
            dispatchUpdate(bounds: nil, phase: .searching, shouldAutoCapture: false)
            return
        }

        guard let observation = rectangleRequest.results?
            .max(by: { $0.confidence < $1.confidence }),
            observation.confidence >= 0.55 else
        {
            stableFrameCount = 0
            dispatchUpdate(bounds: nil, phase: .searching, shouldAutoCapture: false)
            return
        }

        let bounds = mapBounds(observation)
        let alignment = alignmentScore(for: observation)
        updateStability(signature: cornerSignature(observation))

        framesSinceTextProbe += 1
        if framesSinceTextProbe >= 12 {
            framesSinceTextProbe = 0
            probeTextLegibility(pixelBuffer: pixelBuffer, orientation: orientation, observation: observation)
        }

        let phase: DocumentAlignmentPhase = if alignment >= 0.82, stableFrameCount >= 8 {
            textLegibilityScore >= 0.35 ? .ready : .aligning
        } else if alignment >= 0.55 {
            .aligning
        } else {
            .tracking
        }

        let shouldAutoCapture = phase == .ready
            && stableFrameCount >= 10
            && textLegibilityScore >= 0.35

        dispatchUpdate(bounds: bounds, phase: phase, shouldAutoCapture: shouldAutoCapture)
    }

    private func mapBounds(_ observation: VNRectangleObservation) -> DetectedDocumentBounds {
        DetectedDocumentBounds(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomLeft: observation.bottomLeft,
            bottomRight: observation.bottomRight,
            confidence: observation.confidence,
            alignmentScore: alignmentScore(for: observation)
        )
    }

    private func alignmentScore(for observation: VNRectangleObservation) -> Double {
        let edges = [
            hypot(observation.topRight.x - observation.topLeft.x, observation.topRight.y - observation.topLeft.y),
            hypot(
                observation.bottomRight.x - observation.bottomLeft.x,
                observation.bottomRight.y - observation.bottomLeft.y
            ),
            hypot(observation.bottomLeft.x - observation.topLeft.x, observation.bottomLeft.y - observation.topLeft.y),
            hypot(
                observation.bottomRight.x - observation.topRight.x,
                observation.bottomRight.y - observation.topRight.y
            ),
        ]
        let avg = edges.reduce(0, +) / Double(edges.count)
        guard avg > 0.001 else { return 0 }
        let variance = edges.map { abs($0 - avg) / avg }.reduce(0, +) / Double(edges.count)
        let rectangularity = max(0, 1.0 - variance * 4.0)
        return min(1.0, Double(observation.confidence) * 0.35 + rectangularity * 0.65)
    }

    private func cornerSignature(_ observation: VNRectangleObservation) -> [CGFloat] {
        [
            observation.topLeft.x, observation.topLeft.y,
            observation.topRight.x, observation.topRight.y,
            observation.bottomLeft.x, observation.bottomLeft.y,
            observation.bottomRight.x, observation.bottomRight.y,
        ]
    }

    private func updateStability(signature: [CGFloat]) {
        guard !lastSignature.isEmpty, signature.count == lastSignature.count else {
            lastSignature = signature
            stableFrameCount = 0
            return
        }
        let delta = zip(signature, lastSignature).map { abs($0 - $1) }.reduce(0, +)
        if delta < 0.02 {
            stableFrameCount += 1
        } else {
            stableFrameCount = 0
        }
        lastSignature = signature
    }

    private func probeTextLegibility(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        observation: VNRectangleObservation
    ) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.regionOfInterest = observation.boundingBox

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)
            let count = request.results?.count ?? 0
            textLegibilityScore = min(1.0, Double(count) / 6.0)
        } catch {
            textLegibilityScore = 0
        }
    }

    private func dispatchUpdate(
        bounds: DetectedDocumentBounds?,
        phase: DocumentAlignmentPhase,
        shouldAutoCapture: Bool
    ) {
        let callback = onBoundsUpdate
        DispatchQueue.main.async {
            callback?(bounds, phase, shouldAutoCapture)
        }
    }
}
