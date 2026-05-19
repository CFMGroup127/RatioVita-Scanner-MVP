import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Camera permission status
enum CameraPermissionStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unavailable
    
    var displayName: String {
        switch self {
            case .notDetermined: "Not Determined"
            case .denied: "Denied"
            case .restricted: "Restricted"
            case .authorized: "Authorized"
            case .unavailable: "Unavailable"
        }
    }
    
    var canUseCamera: Bool {
        self == .authorized
    }
    
    var requiresPermissionRequest: Bool {
        self == .notDetermined
    }
    
    var requiresSettingsAccess: Bool {
        self == .denied || self == .restricted
    }
}

/// Errors that can occur during scanning operations
enum ScannerError: LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case captureFailed
    case imageProcessingFailed
    case ocrFailed
    case compressionFailed
    case invalidImage
    case processingTimeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
            case .cameraPermissionDenied:
                "Camera permission is required to scan receipts"
            case .cameraUnavailable:
                "Camera is not available on this device"
            case .captureFailed:
                "Failed to capture image from camera"
            case .imageProcessingFailed:
                "Failed to process the captured image"
            case .ocrFailed:
                "Failed to extract text from the image"
            case .compressionFailed:
                "The image will be saved without compression"
            case .invalidImage:
                "The captured image is invalid or corrupted"
            case .processingTimeout:
                "Please try again with a smaller image or disable compression"
            case let .unknown(error):
                "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .cameraPermissionDenied:
                "Please enable camera access in Settings > Privacy & Security > Camera"
            case .cameraUnavailable:
                "Please use a device with a camera or try importing an image from your photo library"
            case .captureFailed:
                "Please try again or check if the camera is being used by another app"
            case .imageProcessingFailed:
                "Please try again with a clearer image"
            case .ocrFailed:
                "Please try again with a clearer image or manually enter the receipt details"
            case .compressionFailed:
                "The image will be saved without compression"
            case .invalidImage:
                "Please try capturing the image again"
            case .processingTimeout:
                "Please try again with a smaller image or disable compression"
            case .unknown:
                "Please try again or contact support if the problem persists"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
            case .cameraPermissionDenied, .cameraUnavailable:
                false
            case .captureFailed, .imageProcessingFailed, .ocrFailed, .compressionFailed, .invalidImage,
                 .processingTimeout:
                true
            case .unknown:
                false
        }
    }
}

/// Configuration options for scanning operations
struct ScannerConfiguration {
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    let compressionQuality: Double
    let maxImageSize: CGSize?
    let ocrRecognitionLevel: OCRRecognitionLevel
    let autoCaptureEnabled: Bool
    let documentDetectionEnabled: Bool
    
    init(
        ocrEnabled: Bool = true,
        compressionEnabled: Bool = true,
        compressionQuality: Double = 0.8,
        maxImageSize: CGSize? = nil,
        ocrRecognitionLevel: OCRRecognitionLevel = .accurate,
        autoCaptureEnabled: Bool = true,
        documentDetectionEnabled: Bool = true
    ) {
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.compressionQuality = max(0.1, min(1.0, compressionQuality))
        self.maxImageSize = maxImageSize
        self.ocrRecognitionLevel = ocrRecognitionLevel
        self.autoCaptureEnabled = autoCaptureEnabled
        self.documentDetectionEnabled = documentDetectionEnabled
    }
}

/// OCR recognition level options
enum OCRRecognitionLevel {
    case fast
    case accurate
    
    var visionLevel: String {
        switch self {
            case .fast: "fast"
            case .accurate: "accurate"
        }
    }
    
    var description: String {
        switch self {
            case .fast: "Fast (lower accuracy)"
            case .accurate: "Accurate (slower processing)"
        }
    }
}

/// Protocol defining the interface for receipt scanning services
protocol ScannerService {
    /// Scans a receipt and returns structured data
    /// - Parameters:
    ///   - ocrEnabled: Whether to perform OCR text recognition
    ///   - compressionEnabled: Whether to compress the captured images
    /// - Returns: A ScanResult containing the scanned pages and extracted data
    /// - Throws: ScannerError if scanning fails
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult
    
    // MARK: - Phase 2: Camera control abstractions (optional to implement)
    
    /// Requests camera permission (iOS)
    func requestCameraPermission() async -> Bool
    
    /// Returns whether a camera is available on this device
    func isCameraAvailable() -> Bool
    
    /// Returns current camera permission status
    func getCameraPermissionStatus() -> CameraPermissionStatus
    
    /// Type-erased preview layer for camera preview.
    /// On iOS, this returns AVCaptureVideoPreviewLayer; on other platforms it may be nil.
    func getVideoPreviewLayer() -> Any?
    
    /// Switches between front and back cameras if supported
    func switchCamera()
    
    /// Focuses the camera at a given point in view coordinates if supported
    func focusCamera(at point: CGPoint)
}

/// Default no-op implementations so conformers don’t need to implement optional hooks
extension ScannerService {
    func requestCameraPermission() async -> Bool { false }
    func isCameraAvailable() -> Bool { false }
    func getCameraPermissionStatus() -> CameraPermissionStatus { .unavailable }
    func getVideoPreviewLayer() -> Any? { nil }
    func switchCamera() {}
    func focusCamera(at _: CGPoint) {}
}
