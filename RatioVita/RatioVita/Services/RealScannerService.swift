#if os(iOS) || os(visionOS)
//
//  RealScannerService.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import AVFoundation
import Foundation
import UIKit
import Vision

/// Production scanner service using AVFoundation and Vision frameworks
class RealScannerService: NSObject, ScannerService {
    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
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
    
    // MARK: - Initialization

    override init() {
        configuration = ScannerConfiguration()
        super.init()
        setupCaptureSession()
    }
    
    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - ScannerService Implementation
    
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // 1) Camera availability
        guard isCameraAvailable() else {
            throw ScannerError.cameraUnavailable
        }
        
        // 2) Permission flow (avoid guard else that doesn't exit)
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
        
        // 3) Start capture session if not running
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
        // For MVP, return single page result
        try await scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)
    }
    
    func processExistingImage(_ image: UIImage, ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // Process existing image (e.g., from photo library)
        let processedImage = try await processImage(image, compressionEnabled: compressionEnabled)
        
        // Perform OCR if enabled
        var ocrText: String?
        var confidence: Double?
        var detectedRectangles: [DetectedRectangle]?
        
        if ocrEnabled {
            let ocrResult = try performOCR(on: processedImage)
            ocrText = ocrResult.text
            confidence = ocrResult.confidence
            detectedRectangles = ocrResult.detectedRectangles
        }
        
        // Create scanned page
        let scannedPage = ScannedPage(
            image: processedImage,
            originalImage: image,
            pageNumber: 1,
            ocrText: ocrText,
            confidence: confidence,
            detectedRectangles: detectedRectangles,
            capturedAt: Date()
        )
        
        // Extract structured data from OCR
        let extractedData = ocrEnabled && ocrText != nil
            ? OCRParsing.extractData(from: ocrText!)
            : ExtractedData()
        
        // Create processing metadata
        let processingSteps = [
            ImageProcessingStep(name: "Image Import", description: "Imported image from library", duration: 0.2),
            ImageProcessingStep(name: "Image Processing", description: "Applied enhancement filters", duration: 0.8),
            ImageProcessingStep(
                name: "OCR Processing",
                description: "Extracted text using Vision framework",
                duration: ocrEnabled ? 1.0 : 0.0
            ),
        ]
        
        let processingMetadata = ProcessingMetadata(
            processingTime: 1.5,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: configuration.compressionQuality,
            imageProcessingSteps: processingSteps
        )
        
        return ScanResult(
            scannedPages: [scannedPage],
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // Configure camera input (fallback for visionOS / single-lens devices)
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
            ?? AVCaptureDevice.default(for: .video)
        guard let camera else {
            #if DEBUG
            print("Failed to get camera device")
            #endif
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(cameraInput) == true {
                captureSession?.addInput(cameraInput)
            }
        } catch {
            #if DEBUG
            print("Failed to create camera input: \(error)")
            #endif
            return
        }
        
        // Configure photo output
        let output = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(output) == true {
            captureSession?.addOutput(output)
            photoOutput = output
        } else {
            photoOutput = nil
        }
        
        // Configure video preview layer
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
        videoPreviewLayer
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        setupCaptureSession()
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
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage.rv_decodedNormalizingEXIFOrientation(from: imageData) else
        {
            onError(ScannerError.invalidImage)
            return
        }
        
        onSuccess(image)
    }
}

// MARK: - OCR Result

private struct OCRResult {
    let text: String
    let confidence: Double
    let detectedRectangles: [DetectedRectangle]
}
#endif
