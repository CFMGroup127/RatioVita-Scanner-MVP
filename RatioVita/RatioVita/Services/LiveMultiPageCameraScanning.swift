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
}

extension ScannerService {
    var liveMultiPageCamera: (any LiveMultiPageCameraScanning)? {
        self as? any LiveMultiPageCameraScanning
    }
}
