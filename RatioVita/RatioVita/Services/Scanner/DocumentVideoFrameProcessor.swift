//
//  DocumentVideoFrameProcessor.swift
//  RatioVita
//
//  AVCaptureVideoDataOutput delegate → DocumentBoundingBoxDetector.
//

import AVFoundation
import Foundation
import Vision

#if os(iOS) || os(visionOS)

final class DocumentVideoFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let detector = DocumentBoundingBoxDetector()
    private var isEnabled = false
    var onBoundsDetected: (@MainActor (DocumentRectangleBounds?) -> Void)?

    func setProcessingEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard isEnabled else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        detector.detectRectangle(in: pixelBuffer, orientation: .right) { [weak self] bounds in
            guard let handler = self?.onBoundsDetected else { return }
            Task { @MainActor in
                handler(bounds)
            }
        }
    }
}

#endif
