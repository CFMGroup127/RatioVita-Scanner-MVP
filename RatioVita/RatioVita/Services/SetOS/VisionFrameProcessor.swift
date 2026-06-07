import AVFoundation
import Foundation
import Vision

/// Camera sample-buffer delegate — isolated from `@MainActor` SwiftUI models (Sprint ZZZ).
final class VisionFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let engine = IntelligentVisionEngine()

    func bindVisionHandler(
        _ handler: @escaping (DetectedDocumentBounds?, DocumentAlignmentPhase, Bool) -> Void
    ) {
        engine.reset()
        engine.onBoundsUpdate = handler
    }

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        engine.process(sampleBuffer: sampleBuffer, orientation: .right)
    }
}
