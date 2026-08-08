#if os(iOS) || os(visionOS)
//
//  RealScannerService.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

@preconcurrency import AVFoundation
import Foundation
import UIKit
import Vision

/// Production scanner service using AVFoundation and Vision frameworks
@MainActor
class RealScannerService: NSObject, ScannerService {
    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private nonisolated let sessionQueue = DispatchQueue(
        label: "com.ratiovita.capture.session",
        qos: .userInitiated
    )
    
    // Camera configuration
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var isSessionRunning = false
    
    // Processing state
    private var isProcessing = false
    private var processingQueue = DispatchQueue(label: "com.ratiovita.scanner.processing", qos: .userInitiated)
    
    // Retain the delegate during capture to avoid early deallocation
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    
    // Configuration
    private let configuration: ScannerConfiguration
    private var isCaptureConfigured = false
    private var isLiveMultiPageSessionActive = false
    
    // MARK: - Initialization

    override init() {
        configuration = ScannerConfiguration()
        super.init()
    }
    
    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init()
    }
    
    // MARK: - ScannerService Implementation
    
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        try await ensureCameraAuthorizedForCapture()
        
        // 3) Configure capture hardware lazily, then start session if not running
        await ensureCaptureConfigured()
        await startCaptureSessionIfNeeded()

        do {
            // 4) Capture image
            let capturedImage = try await captureImage()

            // 5) Process image
            let processedImage = try await processImage(capturedImage, compressionEnabled: compressionEnabled)

            // 6) Perform OCR if enabled
            var ocrText: String?
            var confidence: Double?
            var detectedRectangles: [DetectedRectangle]?

            if ocrEnabled {
                let ocrResult = try performOCR(on: processedImage)
                ocrText = ocrResult.text
                confidence = ocrResult.confidence
                detectedRectangles = ocrResult.detectedRectangles
            }

            // 7) Create scanned page
            let scannedPage = ScannedPage(
                image: processedImage,
                originalImage: capturedImage,
                pageNumber: 1,
                ocrText: ocrText,
                confidence: confidence,
                detectedRectangles: detectedRectangles,
                capturedAt: Date()
            )

            // 8) Extract structured data from OCR
            let extractedData = ocrEnabled && ocrText != nil
                ? OCRParsing.extractData(from: ocrText!)
                : ExtractedData()

            // 9) Create processing metadata
            let processingSteps = [
                ImageProcessingStep(name: "Image Capture", description: "Captured image from camera", duration: 0.5),
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

    // MARK: - LiveMultiPageCameraScanning

    func prepareLiveCameraSession() async throws {
        try await ensureCameraAuthorizedForCapture()

        if isLiveMultiPageSessionActive,
           let captureSession,
           !captureSession.inputs.isEmpty,
           captureSession.isRunning
        {
            #if DEBUG
            print("RatioVita capture: live session already running — skipping re-configure")
            #endif
            notifyCaptureSessionDidStart(captureSession)
            return
        }

        isLiveMultiPageSessionActive = true
        ensureCaptureConfiguredSync()
        guard captureSession != nil, photoOutput != nil else {
            throw ScannerError.captureFailed
        }
        await startCaptureSessionIfNeeded()
        guard captureSession?.isRunning == true else {
            #if DEBUG
            print("RatioVita capture: session failed to start (isRunning=false)")
            #endif
            throw ScannerError.captureFailed
        }
    }

    func captureLiveCameraPhoto() async throws -> UIImage {
        guard isLiveMultiPageSessionActive else {
            throw ScannerError.captureFailed
        }
        let raw = try await captureImage()
        return autoreleasepool {
            LiveMultiPageCaptureImagePrep.normalizedForSessionBuffer(raw)
        }
    }

    func tearDownLiveCameraSession() async {
        isLiveMultiPageSessionActive = false
        currentPhotoDelegate = nil
        await stopCaptureSession()
        await releaseCaptureHardwareAfterLiveSession()
    }

    private func releaseCaptureHardwareAfterLiveSession() async {
        guard let captureSession else { return }
        let session = captureSession

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
                session.commitConfiguration()
                continuation.resume()
            }
        }

        photoOutput = nil
        self.captureSession = nil
        isCaptureConfigured = false
    }

    private func ensureCameraAuthorizedForCapture() async throws {
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
    
    func scanMultiPageReceipt(maxPages _: Int, ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // Live multi-page capture uses `CameraCaptureView` draft pages + `ReceiptScanPipeline.mergedScanResult`.
        // Single shutter API remains one page; library multi-select should call `processImportedImages`.
        try await scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)
    }
    
    func processExistingImage(_ image: UIImage, ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        try await ReceiptScanPipeline.processImported(
            image: image,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled
        )
    }
    
    // MARK: - Private Methods

    private func ensureCaptureConfiguredSync() {
        guard !isCaptureConfigured else { return }
        isCaptureConfigured = setupCaptureSession()
    }

    private func ensureCaptureConfigured() async {
        ensureCaptureConfiguredSync()
    }

    /// Builds inputs/outputs atomically; returns false when hardware cannot be configured.
    @discardableResult
    private func setupCaptureSession() -> Bool {
        if let existing = captureSession,
           !existing.inputs.isEmpty,
           !existing.outputs.isEmpty,
           photoOutput != nil
        {
            #if DEBUG
            print("RatioVita capture: reusing existing session instance")
            #endif
            notifyCaptureSessionDidConfigure(existing)
            return true
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Leave sessionPreset at default — AVFoundation negotiates format at startRunning().

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
            ?? AVCaptureDevice.default(for: .video) else
        {
            #if DEBUG
            print("RatioVita capture: no camera device")
            #endif
            return false
        }

        let cameraInput: AVCaptureDeviceInput
        do {
            cameraInput = try AVCaptureDeviceInput(device: camera)
        } catch {
            #if DEBUG
            print("RatioVita capture: failed to create camera input: \(error)")
            #endif
            return false
        }

        guard session.canAddInput(cameraInput) else {
            #if DEBUG
            print("RatioVita capture: cannot add camera input")
            #endif
            return false
        }
        session.addInput(cameraInput)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            #if DEBUG
            print("RatioVita capture: cannot add photo output")
            #endif
            return false
        }
        session.addOutput(output)

        // No activeFormat, sessionPreset, stabilization, or maxPhotoDimensions overrides —
        // hardware format is negotiated when startRunning() is called on sessionQueue.

        captureSession = session
        photoOutput = output
        #if DEBUG
        print(
            "RatioVita capture: configured session inputs=\(session.inputs.count) "
                + "outputs=\(session.outputs.count) device=\(camera.localizedName)"
        )
        #endif
        notifyCaptureSessionDidConfigure(session)
        return true
    }

    private func notifyCaptureSessionDidConfigure(_ captureSession: AVCaptureSession) {
        NotificationCenter.default.post(name: .ratioVitaCaptureSessionDidConfigure, object: captureSession)
    }

    private func notifyCaptureSessionDidStart(_ captureSession: AVCaptureSession) {
        NotificationCenter.default.post(name: .ratioVitaCaptureSessionDidStart, object: captureSession)
        #if DEBUG
        print(
            "RatioVita capture: started session isRunning=\(captureSession.isRunning) "
                + "inputs=\(captureSession.inputs.count) outputs=\(captureSession.outputs.count)"
        )
        #endif
    }

    private func startCaptureSessionIfNeeded() async {
        guard let captureSession else { return }

        if captureSession.isRunning {
            isSessionRunning = true
            notifyCaptureSessionDidStart(captureSession)
            return
        }

        let session = captureSession
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }

        isSessionRunning = captureSession.isRunning
        if captureSession.isRunning {
            notifyCaptureSessionDidStart(captureSession)
        }
    }

    private func stopCaptureSession() async {
        guard let captureSession, isSessionRunning else { return }

        let session = captureSession
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                session.stopRunning()
                continuation.resume()
            }
        }
        isSessionRunning = false
    }
    
    private func captureImage() async throws -> UIImage {
        guard let photoOutput else {
            throw ScannerError.captureFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            #if os(iOS) || os(visionOS)
            settings.flashMode = .auto
            #endif

            // Retain the delegate until we resume the continuation
            self.currentPhotoDelegate = PhotoCaptureDelegate { image in
                Task { @MainActor in
                    self.currentPhotoDelegate = nil
                }
                continuation.resume(returning: image)
            } onError: { error in
                Task { @MainActor in
                    self.currentPhotoDelegate = nil
                }
                continuation.resume(throwing: error)
            }
            
            if let delegate = self.currentPhotoDelegate {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            } else {
                continuation.resume(throwing: ScannerError.captureFailed)
            }
        }
    }
    
    private func processImage(_ image: UIImage, compressionEnabled _: Bool) async throws -> UIImage {
        // Apply image processing
        let processingOptions = ProcessingOptions.receiptDefault
        let processedImage = try await ImageProcessing.processImage(image, with: processingOptions)
        return processedImage
    }
    
    private func performOCR(on image: UIImage) throws -> OCRResult {
        guard let cgImage = image.cgImage ?? image.rvCGImage else {
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
        return OCRResult(
            text: text,
            confidence: confidence ?? 0,
            detectedRectangles: rectangles
        )
    }
    
    // MARK: - Public Methods for UI Integration

    func getVideoPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        nil
    }

    func avCaptureSessionForPreview() -> AVCaptureSession? {
        captureSession
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        isCaptureConfigured = false
        isSessionRunning = false
        _ = setupCaptureSession()
        isCaptureConfigured = captureSession != nil
    }
    
    func focusCamera(at point: CGPoint) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
            ?? AVCaptureDevice.default(for: .video) else
        {
            return
        }
        
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
            #if DEBUG
            print("Failed to configure camera focus: \(error)")
            #endif
        }
    }
}

extension Notification.Name {
    /// Posted on the main queue after a new `AVCaptureSession` instance is configured.
    static let ratioVitaCaptureSessionDidConfigure = Notification.Name("com.ratiovita.capture.sessionDidConfigure")
    /// Posted on the main queue after `AVCaptureSession.startRunning()` succeeds.
    static let ratioVitaCaptureSessionDidStart = Notification.Name("com.ratiovita.capture.sessionDidStart")
}

extension RealScannerService: LiveMultiPageCameraScanning {}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onSuccess: (UIImage) -> Void
    private let onError: (Error) -> Void
    
    init(onSuccess: @escaping (UIImage) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            onError(error)
            return
        }

        autoreleasepool {
            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage.rv_decodedNormalizingEXIFOrientation(from: imageData) else
            {
                onError(ScannerError.invalidImage)
                return
            }

            let normalized = LiveMultiPageCaptureImagePrep.normalizedForSessionBuffer(image)
            onSuccess(normalized)
        }
    }
}

// MARK: - OCR Result

private struct OCRResult {
    let text: String
    let confidence: Double
    let detectedRectangles: [DetectedRectangle]
}
#endif
