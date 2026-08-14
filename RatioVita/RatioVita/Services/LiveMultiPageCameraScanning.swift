//
//  LiveMultiPageCameraScanning.swift
//  RatioVita
//
//  Keeps AVFoundation running between shutter taps; OCR runs in ReceiptScanPipeline after Done.
//

import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Continuous camera session for multi-page receipt capture before batch OCR.
protocol LiveMultiPageCameraScanning: ScannerService {
    func prepareLiveCameraSession() async throws
    func captureLiveCameraPhoto() async throws -> RVImage
    func tearDownLiveCameraSession() async

    /// Latest detected document frame (normalized Vision coordinates).
    @MainActor var liveDocumentBounds: DocumentRectangleBounds? { get }

    /// Receives throttled rectangle updates while the live session is active.
    @MainActor func setLiveDocumentBoundsHandler(_ handler: (@MainActor (DocumentRectangleBounds?) -> Void)?)
}

extension ScannerService {
    var liveMultiPageCamera: (any LiveMultiPageCameraScanning)? {
        self as? any LiveMultiPageCameraScanning
    }
}

extension LiveMultiPageCameraScanning {
    @MainActor var liveDocumentBounds: DocumentRectangleBounds? { nil }

    @MainActor func setLiveDocumentBoundsHandler(_: (@MainActor (DocumentRectangleBounds?) -> Void)?) {}
}
