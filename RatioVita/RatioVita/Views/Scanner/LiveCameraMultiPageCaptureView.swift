//
//  LiveCameraMultiPageCaptureView.swift
//  RatioVita
//
//  Live viewfinder + sequential shutter captures → batch handoff to ReceiptScanPipeline.
//

import Combine
import SwiftUI

#if os(iOS) || os(visionOS)
import AVFoundation
import UIKit

struct LiveCameraMultiPageCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let liveScanner: any LiveMultiPageCameraScanning
    let onProcessBatch: @MainActor (_ images: [UIImage]) async -> Void

    @StateObject private var buffer = MultiPageScanBuffer()
    @State private var isPreparing = true
    @State private var isCapturing = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var liveSessionTornDown = false

    @State private var isPreviewSessionReady = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ReceiptLiveCameraPreviewRepresentable(
                    scanner: liveScanner,
                    sessionReady: isPreviewSessionReady
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    thumbnailStrip
                    controls
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)

                if isPreparing || isProcessing {
                    ProgressView(isProcessing ? "Processing batch…" : "Starting camera…")
                        .padding(DesignSystem.Spacing.lg)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Scan pages")
            #if !os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            Task { await closeSession() }
                        }
                        .disabled(isProcessing)
                    }
                }
                .task {
                    await openSession()
                }
                .onDisappear {
                    Task { await tearDownLiveSessionIfNeeded(clearBuffer: true) }
                }
        }
    }

    private var thumbnailStrip: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(buffer.count == 0 ? "No pages yet" : "\(buffer.count) page\(buffer.count == 1 ? "" : "s") captured")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaError)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(buffer.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: page.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 72)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                                }
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .padding(4)
                                .background(.black.opacity(0.55), in: Circle())
                                .foregroundStyle(.white)
                                .padding(4)
                            Button {
                                buffer.remove(id: page.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .offset(x: 6, y: -6)
                        }
                        .frame(width: 64, height: 80)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: buffer.isEmpty ? 0 : 88)
            .clipped()
        }
    }

    private var controls: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Button {
                Task { await snapPhoto() }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                }
            }
            .buttonStyle(.plain)
            .disabled(isPreparing || isCapturing || isProcessing)

            Button {
                Task { await finishBatch() }
            } label: {
                Text(buffer.count > 0 ? "Done (\(buffer.count))" : "Done")
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ratioVitaPrimary)
            .disabled(buffer.isEmpty || isProcessing || isCapturing)
        }
    }

    @MainActor
    private func tearDownLiveSessionIfNeeded(clearBuffer: Bool) async {
        guard !liveSessionTornDown else { return }
        liveSessionTornDown = true
        isPreviewSessionReady = false
        if clearBuffer {
            buffer.clear()
        }
        await liveScanner.tearDownLiveCameraSession()
    }

    @MainActor
    private func openSession() async {
        isPreparing = true
        errorMessage = nil
        isPreviewSessionReady = false
        defer { isPreparing = false }
        do {
            try await liveScanner.prepareLiveCameraSession()
            isPreviewSessionReady = true
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func closeSession() async {
        await tearDownLiveSessionIfNeeded(clearBuffer: true)
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }
        do {
            let image = try await liveScanner.captureLiveCameraPhoto()
            autoreleasepool {
                buffer.append(image)
            }
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func finishBatch() async {
        guard !buffer.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        let batch = buffer.images
        await tearDownLiveSessionIfNeeded(clearBuffer: false)
        await onProcessBatch(batch)
        buffer.clear()
        dismiss()
    }
}

private struct ReceiptLiveCameraPreviewRepresentable: UIViewControllerRepresentable {
    let scanner: any ScannerService
    var sessionReady: Bool

    func makeUIViewController(context _: Context) -> LiveCameraPreviewViewController {
        let controller = LiveCameraPreviewViewController()
        controller.scanner = scanner
        controller.sessionReady = sessionReady
        return controller
    }

    func updateUIViewController(_ uiViewController: LiveCameraPreviewViewController, context _: Context) {
        uiViewController.scanner = scanner
        uiViewController.sessionReady = sessionReady
        uiViewController.syncPreviewIfNeeded()
    }
}

/// Hosts an `AVCaptureVideoPreviewLayer` as the root view layer and binds the running capture session.
final class LiveCameraPreviewViewController: UIViewController {
    var scanner: (any ScannerService)?
    var sessionReady = false

    private let previewHost = CameraPreviewRootView()

    override func loadView() {
        view = previewHost
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncPreviewIfNeeded()
    }

    func syncPreviewIfNeeded() {
        guard sessionReady else {
            previewHost.bindCaptureSession(nil)
            return
        }
        guard let session = scanner?.avCaptureSessionForPreview() else { return }
        previewHost.bindCaptureSession(session)
    }
}

final class CameraPreviewRootView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer as root layer")
        }
        return layer
    }

    func bindCaptureSession(_ session: AVCaptureSession?) {
        previewLayer.videoGravity = .resizeAspectFill
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        previewLayer.connection?.isEnabled = session != nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

#endif

#if os(macOS)
import AppKit
import AVFoundation

struct LiveCameraMultiPageCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let liveScanner: any LiveMultiPageCameraScanning
    let onProcessBatch: @MainActor (_ images: [NSImage]) async -> Void

    @StateObject private var buffer = MultiPageScanBuffer()
    @State private var isPreparing = true
    @State private var isCapturing = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var liveSessionTornDown = false

    @State private var isPreviewSessionReady = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = SafeLayoutBounds.clampedLayoutDimension(
                    geometry.size.width,
                    max: SafeLayoutBounds.maxWorkspaceContentWidth
                )
                let height = SafeLayoutBounds.clampedLayoutDimension(
                    geometry.size.height,
                    max: SafeLayoutBounds.maxWindowHeight
                )

                ZStack {
                    Color.black
                    ReceiptLiveCameraPreviewRepresentableMac(
                        scanner: liveScanner,
                        sessionReady: isPreviewSessionReady
                    )
                    .frame(width: width, height: height)
                    .clipped()

                    VStack {
                        Spacer(minLength: 0)
                        macThumbnailStrip
                            .frame(maxWidth: width)
                        macControls
                            .frame(maxWidth: width)
                    }
                    .padding(DesignSystem.Spacing.md)

                    if isPreparing || isProcessing {
                        ProgressView(isProcessing ? "Processing batch…" : "Starting camera…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(width: width, height: height)
            }
            .navigationTitle("Scan pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Task { await closeSession() }
                    }
                }
            }
            .task { await openSession() }
            .onDisappear {
                Task { await tearDownLiveSessionIfNeeded(clearBuffer: true) }
            }
        }
        .frame(
            minWidth: 640,
            idealWidth: 960,
            maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth,
            minHeight: 480,
            idealHeight: 640,
            maxHeight: SafeLayoutBounds.maxWindowHeight
        )
    }

    private var macThumbnailStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(buffer.count == 0 ? "No pages yet" : "\(buffer.count) page(s) captured")
                .font(DesignSystem.Typography.caption.weight(.semibold))
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.ratioVitaError)
                    .font(.caption)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(buffer.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: page.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 72)
                                .clipped()
                            Text("\(index + 1)")
                                .font(.caption2)
                                .padding(2)
                            Button("×") { buffer.remove(id: page.id) }
                                .buttonStyle(.plain)
                        }
                        .frame(width: 64, height: 80)
                    }
                }
            }
            .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth)
            .frame(height: buffer.isEmpty ? 0 : 80)
            .clipped()
        }
    }

    private var macControls: some View {
        HStack {
            Button("Capture page") {
                Task { await snapPhoto() }
            }
            .disabled(isPreparing || isCapturing || isProcessing)
            Button(buffer.count > 0 ? "Done (\(buffer.count))" : "Done") {
                Task { await finishBatch() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(buffer.isEmpty || isProcessing)
        }
    }

    @MainActor
    private func tearDownLiveSessionIfNeeded(clearBuffer: Bool) async {
        guard !liveSessionTornDown else { return }
        liveSessionTornDown = true
        isPreviewSessionReady = false
        if clearBuffer {
            buffer.clear()
        }
        await liveScanner.tearDownLiveCameraSession()
    }

    @MainActor
    private func openSession() async {
        isPreparing = true
        isPreviewSessionReady = false
        defer { isPreparing = false }
        do {
            try await liveScanner.prepareLiveCameraSession()
            isPreviewSessionReady = true
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func closeSession() async {
        await tearDownLiveSessionIfNeeded(clearBuffer: true)
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            let image = try await liveScanner.captureLiveCameraPhoto()
            autoreleasepool {
                buffer.append(image)
            }
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func finishBatch() async {
        guard !buffer.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        let batch = buffer.images
        await tearDownLiveSessionIfNeeded(clearBuffer: false)
        await onProcessBatch(batch)
        buffer.clear()
        dismiss()
    }
}

private struct ReceiptLiveCameraPreviewRepresentableMac: NSViewControllerRepresentable {
    let scanner: any ScannerService
    var sessionReady: Bool

    func makeNSViewController(context _: Context) -> LiveCameraPreviewViewControllerMac {
        let controller = LiveCameraPreviewViewControllerMac()
        controller.scanner = scanner
        controller.sessionReady = sessionReady
        return controller
    }

    func updateNSViewController(_ controller: LiveCameraPreviewViewControllerMac, context _: Context) {
        controller.scanner = scanner
        controller.sessionReady = sessionReady
        controller.syncPreviewIfNeeded()
    }
}

final class LiveCameraPreviewViewControllerMac: NSViewController {
    var scanner: (any ScannerService)?
    var sessionReady = false

    private let previewHost = MacCameraPreviewRootView()

    override func loadView() {
        view = previewHost
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncPreviewIfNeeded()
    }

    func syncPreviewIfNeeded() {
        guard sessionReady else {
            previewHost.bindCaptureSession(nil)
            return
        }
        guard let session = scanner?.avCaptureSessionForPreview() else { return }
        previewHost.bindCaptureSession(session)
    }
}

final class MacCameraPreviewRootView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    func bindCaptureSession(_ session: AVCaptureSession?) {
        if session == nil {
            previewLayer?.session = nil
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
            return
        }
        guard let session else { return }
        let layer: AVCaptureVideoPreviewLayer
        if let existing = previewLayer {
            layer = existing
        } else {
            let created = AVCaptureVideoPreviewLayer(session: session)
            created.videoGravity = .resizeAspectFill
            self.layer?.addSublayer(created)
            previewLayer = created
            layer = created
        }
        if layer.session !== session {
            layer.session = session
        }
        layer.connection?.isEnabled = true
        layer.frame = bounds
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
#endif
