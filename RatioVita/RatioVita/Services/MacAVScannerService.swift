#if os(macOS)
//
//  MacAVScannerService.swift
//  RatioVita
//
//  macOS: FaceTime / built-in / Continuity / external USB cameras via AVFoundation,
//  then the same Sovereign ImageProcessing + Vision path as iOS.
//

import AppKit
import AVFoundation
import Foundation
import Vision

/// Production scanner for macOS using AVFoundation photo capture + Vision OCR.
final class MacAVScannerService: NSObject, ScannerService {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    private var availableDevices: [AVCaptureDevice] = []
    private var selectedDeviceIndex = 0
    private var isSessionRunning = false

    private var currentPhotoDelegate: MacPhotoCaptureDelegate?

    private let configuration: ScannerConfiguration

    override init() {
        configuration = ScannerConfiguration()
        super.init()
        refreshDeviceList()
        setupCaptureSession()
    }

    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init()
        refreshDeviceList()
        setupCaptureSession()
    }

    // MARK: - ScannerService

    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        guard isCameraAvailable() else {
            throw ScannerError.cameraUnavailable
        }

        let status = getCameraPermissionStatus()
        switch status {
            case .authorized:
                break
            case .notDetermined:
                let granted = await requestCameraPermission()
                guard granted else {
                    throw ScannerError.cameraPermissionDenied
                }
            case .denied, .restricted, .unavailable:
                throw ScannerError.cameraPermissionDenied
        }

        await startCaptureSessionIfNeeded()

        do {
            let capturedImage = try await captureImage()
            let processedImage = try await processImage(capturedImage, compressionEnabled: compressionEnabled)

            var ocrText: String?
            var confidence: Double?
            var detectedRectangles: [DetectedRectangle]?

            if ocrEnabled {
                let ocrResult = try performOCR(on: processedImage)
                ocrText = ocrResult.text
                confidence = ocrResult.confidence
                detectedRectangles = ocrResult.detectedRectangles
            }

            let scannedPage = ScannedPage(
                image: processedImage,
                originalImage: capturedImage,
                pageNumber: 1,
                ocrText: ocrText,
                confidence: confidence,
                detectedRectangles: detectedRectangles,
                capturedAt: Date()
            )

            let extractedData = ocrEnabled && ocrText != nil
                ? OCRParsing.extractData(from: ocrText!)
                : ExtractedData()

            let processingSteps = [
                ImageProcessingStep(
                    name: "Image Capture",
                    description: "Captured image from Mac camera",
                    duration: 0.5
                ),
                ImageProcessingStep(
                    name: "Image Processing",
                    description: "Applied enhancement filters",
                    duration: 0.8
                ),
                ImageProcessingStep(
                    name: "OCR Processing",
                    description: "Extracted text using Vision framework",
                    duration: ocrEnabled ? 1.2 : 0.0
                ),
            ]

            let processingMetadata = ProcessingMetadata(
                processingTime: 2.0,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled,
                compressionQuality: configuration.compressionQuality,
                imageProcessingSteps: processingSteps
            )

            let scanResult = ScanResult(
                scannedPages: [scannedPage],
                extractedData: extractedData,
                processingMetadata: processingMetadata
            )
            await stopCaptureSession()
            return scanResult
        } catch {
            await stopCaptureSession()
            throw error
        }
    }

    func requestCameraPermission() async -> Bool {
        await CameraPermissions.requestCameraPermission()
    }

    func isCameraAvailable() -> Bool {
        CameraPermissions.isCameraAvailable()
    }

    func getCameraPermissionStatus() -> CameraPermissionStatus {
        CameraPermissions.getCameraPermissionStatus()
    }

    func getVideoPreviewLayer() -> Any? {
        videoPreviewLayer
    }

    func switchCamera() {
        guard !availableDevices.isEmpty else { return }
        selectedDeviceIndex = (selectedDeviceIndex + 1) % availableDevices.count
        setupCaptureSession()
    }

    func focusCamera(at point: CGPoint) {
        guard selectedDeviceIndex < availableDevices.count else { return }
        let device = availableDevices[selectedDeviceIndex]
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure camera focus: \(error)")
        }
    }

    // MARK: - Private

    private func refreshDeviceList() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableDevices = discovery.devices
        if availableDevices.isEmpty, let fallback = AVCaptureDevice.default(for: .video) {
            availableDevices = [fallback]
        }
        selectedDeviceIndex = min(selectedDeviceIndex, max(availableDevices.count - 1, 0))
    }

    private func setupCaptureSession() {
        if let session = captureSession, isSessionRunning {
            session.stopRunning()
            isSessionRunning = false
        }

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        refreshDeviceList()
        guard !availableDevices.isEmpty else {
            print("Failed to get camera device")
            return
        }

        let camera = availableDevices[selectedDeviceIndex]

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(cameraInput) == true {
                captureSession?.addInput(cameraInput)
            }
        } catch {
            print("Failed to create camera input: \(error)")
            return
        }

        let output = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(output) == true {
            captureSession?.addOutput(output)
            photoOutput = output
        } else {
            photoOutput = nil
        }

        if let session = captureSession {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            videoPreviewLayer = layer
        } else {
            videoPreviewLayer = nil
        }
    }

    private func startCaptureSessionIfNeeded() async {
        guard let captureSession, !isSessionRunning else { return }
        await MainActor.run {
            captureSession.startRunning()
            isSessionRunning = true
        }
    }

    private func stopCaptureSession() async {
        guard let captureSession, isSessionRunning else { return }
        await MainActor.run {
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }

    private func captureImage() async throws -> NSImage {
        guard let photoOutput else {
            throw ScannerError.captureFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            self.currentPhotoDelegate = MacPhotoCaptureDelegate { image in
                self.currentPhotoDelegate = nil
                continuation.resume(returning: image)
            } onError: { error in
                self.currentPhotoDelegate = nil
                continuation.resume(throwing: error)
            }

            if let delegate = self.currentPhotoDelegate {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            } else {
                continuation.resume(throwing: ScannerError.captureFailed)
            }
        }
    }

    private func processImage(_ image: NSImage, compressionEnabled _: Bool) async throws -> NSImage {
        let processingOptions = ProcessingOptions.receiptDefault
        return try await ImageProcessing.processImage(image, with: processingOptions)
    }

    private func performOCR(on image: NSImage) throws -> MacOCRResult {
        guard let cgImage = image.rvCGImage else {
            throw ScannerError.ocrFailed
        }
        let level: VNRequestTextRecognitionLevel = configuration.ocrRecognitionLevel == .fast ? .fast : .accurate
        let (ocrText, confidence, rectangles) = try VisionReceiptAnalysis.analyzeReceipt(
            cgImage: cgImage,
            ocrEnabled: true,
            textRecognitionLevel: level
        )
        guard let text = ocrText else {
            throw ScannerError.ocrFailed
        }
        return MacOCRResult(
            text: text,
            confidence: confidence ?? 0,
            detectedRectangles: rectangles
        )
    }
}

// MARK: - Photo Capture Delegate

private final class MacPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onSuccess: (NSImage) -> Void
    private let onError: (Error) -> Void

    init(onSuccess: @escaping (NSImage) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            onError(error)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = RVImage.rv_decodedNormalizingEXIFOrientation(from: imageData) ?? NSImage(data: imageData) else
        {
            onError(ScannerError.invalidImage)
            return
        }

        onSuccess(image)
    }
}

private struct MacOCRResult {
    let text: String
    let confidence: Double
    let detectedRectangles: [DetectedRectangle]
}
#else
import Foundation
#endif
