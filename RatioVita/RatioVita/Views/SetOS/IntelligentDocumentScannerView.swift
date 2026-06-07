import AVFoundation
import Combine
import SwiftUI
import Vision

#if os(iOS)
import UIKit
#endif

// MARK: - Capture session (background queue)

private final class IntelligentOpticalCaptureSession: NSObject, @unchecked Sendable {
    let avSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let photoOutput = AVCapturePhotoOutput()
    let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "com.ratiovita.intelligent.capture")

    func configure(completion: @escaping @Sendable (String?) -> Void) {
        sessionQueue.async {
            var configError: String?
            self.avSession.beginConfiguration()
            defer { self.avSession.commitConfiguration() }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else
            {
                configError = "Camera unavailable on this device."
                completion(configError)
                return
            }
            if self.avSession.canAddInput(input) { self.avSession.addInput(input) }

            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            if self.avSession.canAddOutput(self.videoOutput) {
                self.avSession.addOutput(self.videoOutput)
            }
            if self.avSession.canAddOutput(self.photoOutput) {
                self.avSession.addOutput(self.photoOutput)
                // Seed valid still dimensions; an unconfigured photo output reports
                // {0,0}, which makes AVFoundation emit err=-12710
                // (kCMFormatDescriptionError_InvalidParameter) when probing the format.
                if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *),
                   let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.last {
                    self.photoOutput.maxPhotoDimensions = maxDimensions
                }
            }
            if self.avSession.canAddOutput(self.metadataOutput) {
                self.avSession.addOutput(self.metadataOutput)
                self.metadataOutput.metadataObjectTypes = [
                    .qr, .ean13, .ean8, .code128, .code39, .dataMatrix, .pdf417,
                ]
            }
            completion(configError)
        }
    }

    func setVideoDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(
                delegate,
                queue: DispatchQueue(label: "com.ratiovita.intelligent.frames")
            )
        }
    }

    func setMetadataDelegate(_ delegate: AVCaptureMetadataOutputObjectsDelegate) {
        sessionQueue.async {
            self.metadataOutput.setMetadataObjectsDelegate(
                delegate,
                queue: DispatchQueue(label: "com.ratiovita.intelligent.metadata")
            )
        }
    }

    func capturePhoto(delegate: AVCapturePhotoCaptureDelegate) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
                let dimensions = self.photoOutput.maxPhotoDimensions
                if dimensions.width > 0, dimensions.height > 0 {
                    settings.maxPhotoDimensions = dimensions
                }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func startRunning(completion: @escaping @Sendable () -> Void) {
        sessionQueue.async {
            if !self.avSession.isRunning { self.avSession.startRunning() }
            completion()
        }
    }

    func stopRunning(completion: @escaping @Sendable () -> Void) {
        sessionQueue.async {
            if self.avSession.isRunning { self.avSession.stopRunning() }
            completion()
        }
    }
}

// MARK: - Model

@MainActor
final class IntelligentDocumentScannerModel: NSObject, ObservableObject {
    @Published var detectedBounds: DetectedDocumentBounds?
    @Published var alignmentPhase: DocumentAlignmentPhase = .searching
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var lastCapturedNote: String?
    @Published var lastScannedBarcode: String?

    private let capture = IntelligentOpticalCaptureSession()
    private let frameProcessor = VisionFrameProcessor()
    private var onCapture: ((String) -> Void)?
    private var onBarcode: ((String) -> Void)?
    private var autoCaptureCooldown = false
    var scanMode: ScanSurfaceMode = .intelligentDocument

    enum ScanSurfaceMode {
        case intelligentDocument
        case barcodeOnly
    }

    #if os(iOS)
    var sessionForPreview: AVCaptureSession { capture.avSession }
    #endif

    func start(
        mode: ScanSurfaceMode = .intelligentDocument,
        onCapture: @escaping (String) -> Void,
        onBarcode: ((String) -> Void)? = nil
    ) {
        scanMode = mode
        self.onCapture = onCapture
        self.onBarcode = onBarcode
        frameProcessor.bindVisionHandler { bounds, phase, shouldAutoCapture in
            Task { @MainActor [weak self] in
                guard let self else { return }
                applyVision(
                    bounds: bounds,
                    phase: phase,
                    shouldAutoCapture: shouldAutoCapture
                )
            }
        }
        capture.configure { error in
            Task { @MainActor [weak self] in
                await self?.applyConfigure(error: error)
            }
        }
    }

    func stop() {
        capture.stopRunning {
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.detectedBounds = nil
                self?.alignmentPhase = .searching
            }
        }
    }

    func manualShutter() {
        capture.capturePhoto(delegate: self)
    }

    private func applyConfigure(error: String?) async {
        if let error {
            errorMessage = error
            return
        }
        capture.setVideoDelegate(frameProcessor)
        capture.setMetadataDelegate(self)
        capture.startRunning {
            Task { @MainActor [weak self] in
                self?.isRunning = true
            }
        }
    }

    private func applyVision(
        bounds: DetectedDocumentBounds?,
        phase: DocumentAlignmentPhase,
        shouldAutoCapture: Bool
    ) {
        guard scanMode == .intelligentDocument else { return }
        detectedBounds = bounds
        alignmentPhase = phase
        if shouldAutoCapture, !autoCaptureCooldown {
            autoCaptureCooldown = true
            manualShutter()
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                autoCaptureCooldown = false
            }
        }
    }
}

extension IntelligentDocumentScannerModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error _: Error?
    ) {
        guard let data = photo.fileDataRepresentation() else { return }
        let token = "DOC-\(data.count)-\(Int(Date().timeIntervalSince1970))"
        Task { @MainActor [weak self] in
            self?.lastCapturedNote = "Captured \(data.count / 1024) KB · \(token)"
            _ = HardwareIngestionManager.shared.ingestOptical(token)
            self?.onCapture?(token)
        }
    }
}

extension IntelligentDocumentScannerModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        Task { @MainActor [weak self] in
            guard HardwareIngestionManager.shared.ingestOptical(value) != nil else { return }
            self?.lastScannedBarcode = value
            self?.onBarcode?(value)
        }
    }
}

// MARK: - UI

struct IntelligentDocumentScannerView: View {
    var onCapture: (String) -> Void
    var onBarcode: ((String) -> Void)?

    @StateObject private var model = IntelligentDocumentScannerModel()
    @State private var surfaceMode: IntelligentDocumentScannerModel.ScanSurfaceMode = .intelligentDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Scan mode", selection: $surfaceMode) {
                Text("Document · auto-shutter").tag(IntelligentDocumentScannerModel.ScanSurfaceMode.intelligentDocument)
                Text("Barcode / QR").tag(IntelligentDocumentScannerModel.ScanSurfaceMode.barcodeOnly)
            }
            .pickerStyle(.segmented)
            .onChange(of: surfaceMode) { _, newValue in
                if model.isRunning {
                    model.stop()
                    model.start(mode: newValue, onCapture: onCapture, onBarcode: onBarcode)
                }
            }

            #if os(iOS)
            ZStack {
                IntelligentCameraPreviewRepresentable(session: model.sessionForPreview)
                    .frame(height: 320)
                if surfaceMode == .intelligentDocument {
                    DocumentBoundsOverlay(
                        bounds: model.detectedBounds,
                        phase: model.alignmentPhase
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            #else
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(height: 160)
                .overlay {
                    Text("Live intelligent capture requires iOS or iPadOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            #endif

            statusRow

            HStack(spacing: 12) {
                Button(model.isRunning ? "Stop" : "Start camera") {
                    if model.isRunning {
                        model.stop()
                    } else {
                        model.start(mode: surfaceMode, onCapture: onCapture, onBarcode: onBarcode)
                    }
                }
                .buttonStyle(.bordered)

                #if os(iOS)
                Button {
                    model.manualShutter()
                } label: {
                    Label("Capture", systemImage: "camera.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isRunning || surfaceMode == .barcodeOnly)
                #endif
            }
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if surfaceMode == .intelligentDocument {
                Label(phaseLabel, systemImage: phaseIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(phaseColor)
                Text("Hold steady — overlay turns green when aligned; auto-shutter fires when text is legible.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let note = model.lastCapturedNote {
                Text(note).font(.caption.monospaced())
            }
            if let code = model.lastScannedBarcode {
                Text("Barcode: \(code)").font(.caption.monospaced())
            }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var phaseLabel: String {
        switch model.alignmentPhase {
            case .searching: "Searching for document…"
            case .tracking: "Document detected"
            case .aligning: "Level device — aligning"
            case .ready: "Aligned · ready to capture"
        }
    }

    private var phaseIcon: String {
        switch model.alignmentPhase {
            case .searching: "viewfinder"
            case .tracking: "rectangle.dashed"
            case .aligning: "level"
            case .ready: "checkmark.rectangle.fill"
        }
    }

    private var phaseColor: Color {
        switch model.alignmentPhase {
            case .searching: .secondary
            case .tracking: .yellow
            case .aligning: .orange
            case .ready: .green
        }
    }
}

#if os(iOS)
private struct DocumentBoundsOverlay: View {
    let bounds: DetectedDocumentBounds?
    let phase: DocumentAlignmentPhase

    var body: some View {
        GeometryReader { geo in
            if let bounds {
                let path = quadPath(bounds: bounds, in: geo.size)
                path.stroke(strokeColor, lineWidth: 3)
                path.fill(strokeColor.opacity(0.12))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(32)
            }
        }
        .allowsHitTesting(false)
    }

    private var strokeColor: Color {
        switch phase {
            case .ready: .green
            case .aligning: .orange
            case .tracking: .yellow
            case .searching: .white.opacity(0.5)
        }
    }

    private func quadPath(bounds: DetectedDocumentBounds, in size: CGSize) -> Path {
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
        }
        var path = Path()
        path.move(to: map(bounds.topLeft))
        path.addLine(to: map(bounds.topRight))
        path.addLine(to: map(bounds.bottomRight))
        path.addLine(to: map(bounds.bottomLeft))
        path.closeSubpath()
        return path
    }
}

private struct IntelligentCameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
#endif
