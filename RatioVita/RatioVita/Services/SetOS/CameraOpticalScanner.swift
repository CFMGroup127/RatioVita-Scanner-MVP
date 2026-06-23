import AVFoundation
import Combine
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Background capture session (Swift 6 — session off MainActor)

private final class OpticalCaptureSession: @unchecked Sendable {
    let avSession = AVCaptureSession()
    let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "com.ratiovita.optical.session")

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
            if self.avSession.canAddOutput(self.metadataOutput) {
                self.avSession.addOutput(self.metadataOutput)
                self.metadataOutput.metadataObjectTypes = [
                    .qr, .ean13, .ean8, .code128, .code39, .dataMatrix, .pdf417,
                ]
            }
            completion(nil)
        }
    }

    func setMetadataDelegate(_ delegate: AVCaptureMetadataOutputObjectsDelegate) {
        sessionQueue.async {
            self.metadataOutput.setMetadataObjectsDelegate(
                delegate,
                queue: DispatchQueue(label: "com.ratiovita.optical.scan")
            )
        }
    }

    func startRunning(completion: @escaping @Sendable () -> Void) {
        sessionQueue.async {
            if !self.avSession.isRunning {
                self.avSession.startRunning()
            }
            completion()
        }
    }

    func stopRunning(completion: @escaping @Sendable () -> Void) {
        sessionQueue.async {
            if self.avSession.isRunning {
                self.avSession.stopRunning()
            }
            completion()
        }
    }
}

/// Native QR / barcode capture via AVFoundation (Sprint WWW).
@MainActor
final class CameraOpticalScannerModel: NSObject, ObservableObject {
    @Published var lastScannedValue: String?
    @Published var isRunning = false
    @Published var errorMessage: String?

    private let capture = OpticalCaptureSession()
    private var onScan: ((String) -> Void)?

    #if os(iOS)
    var sessionForPreview: AVCaptureSession { capture.avSession }
    #endif

    func startScanning(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        capture.configure { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.applyConfigure(error: error)
            }
        }
    }

    func stopScanning() {
        capture.stopRunning { [weak self] in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    private func applyConfigure(error: String?) async {
        if let error {
            errorMessage = error
            return
        }
        capture.setMetadataDelegate(self)
        capture.startRunning { [weak self] in
            Task { @MainActor [weak self] in
                self?.isRunning = true
            }
        }
    }
}

extension CameraOpticalScannerModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard HardwareIngestionManager.shared.ingestOptical(value) != nil else { return }
            lastScannedValue = value
            onScan?(value)
        }
    }
}

struct CameraOpticalScannerView: View {
    @StateObject private var model = CameraOpticalScannerModel()
    var onScan: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            CameraPreviewRepresentable(session: model.sessionForPreview)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            #else
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(height: 120)
                .overlay {
                    Text("Camera preview · use iOS/iPad for live optical scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            #endif
            if let last = model.lastScannedValue {
                Text("Last scan: \(last)")
                    .font(.caption.monospaced())
            }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Button(model.isRunning ? "Stop camera" : "Open camera scanner") {
                    if model.isRunning {
                        model.stopScanning()
                    } else {
                        model.startScanning(onScan: onScan)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onDisappear { model.stopScanning() }
    }
}

#if os(iOS)
private struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
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
