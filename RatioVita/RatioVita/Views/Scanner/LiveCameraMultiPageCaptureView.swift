//
//  LiveCameraMultiPageCaptureView.swift
//  RatioVita
//
//  Live viewfinder + sequential shutter captures → disk-backed batch → ReceiptScanPipeline on Finish Scan.
//

import Combine
import SwiftUI

#if os(iOS) || os(visionOS)
import AVFoundation
import UIKit

struct LiveCameraMultiPageCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let liveScanner: any LiveMultiPageCameraScanning
    let onProcessBatch: @MainActor (_ pageURLs: [URL]) async -> Void

    @ObservedObject private var batch = ReceiptBatchManager.shared
    @State private var isPreparing = true
    @State private var isCapturing = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var liveSessionTornDown = false
    @State private var isPreviewSessionReady = false
    @State private var captureSessionOpened = false

    var body: some View {
        NavigationStack {
            ZStack {
                ReceiptLiveCameraPreviewRepresentable(
                    scanner: liveScanner,
                    sessionReady: isPreviewSessionReady
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Task { await tearDownLiveSessionIfNeeded(clearBatch: true) }
                }
        }
    }

    private var thumbnailStrip: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(batch
                .pageCount == 0 ? "No pages yet" : "\(batch.pageCount) page\(batch.pageCount == 1 ? "" : "s") captured")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(Color.ratioVitaError)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(batch.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            ReceiptBatchThumbnailView(thumbnailURL: page.thumbnailURL)
                                .frame(width: 56, height: 72)
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
                                batch.removePage(at: index)
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
            .frame(height: batch.isEmpty ? 0 : 88)
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
                Text(batch.pageCount > 0 ? "Finish Scan (\(batch.pageCount))" : "Finish Scan")
                    .font(DesignSystem.Typography.bodyEmphasized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ratioVitaPrimary)
            .disabled(batch.isEmpty || isProcessing || isCapturing)
        }
    }

    @MainActor
    private func tearDownLiveSessionIfNeeded(clearBatch: Bool) async {
        guard !liveSessionTornDown else { return }
        liveSessionTornDown = true
        isPreviewSessionReady = false
        if clearBatch {
            batch.endSession(deleteFiles: true)
        }
        await liveScanner.tearDownLiveCameraSession()
    }

    @MainActor
    private func openSession() async {
        guard !captureSessionOpened else { return }
        captureSessionOpened = true
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }
        do {
            try batch.beginSession()
            try await liveScanner.prepareLiveCameraSession()
            isPreviewSessionReady = true
        } catch {
            captureSessionOpened = false
            errorMessage = error.ratioVitaUserDescription
            batch.endSession(deleteFiles: true)
        }
    }

    @MainActor
    private func closeSession() async {
        await tearDownLiveSessionIfNeeded(clearBatch: true)
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }
        do {
            let image = try await liveScanner.captureLiveCameraPhoto()
            try batch.appendCapturedImage(image)
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func finishBatch() async {
        guard !batch.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        let urls = batch.pageURLs
        await tearDownLiveSessionIfNeeded(clearBatch: false)
        await onProcessBatch(urls)
        batch.endSession(deleteFiles: true)
        dismiss()
    }
}

/// Loads a small on-disk thumb for the live capture strip (never holds full pages in view state).
private struct ReceiptBatchThumbnailView: View {
    let thumbnailURL: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.12)
            }
        }
        .task(id: thumbnailURL) {
            image = await Task.detached(priority: .utility) {
                guard let data = try? Data(contentsOf: thumbnailURL, options: [.mappedIfSafe]),
                      let decoded = UIImage(data: data) else { return nil as UIImage? }
                return decoded
            }.value
        }
    }
}

private struct ReceiptLiveCameraPreviewRepresentable: UIViewControllerRepresentable {
    let scanner: any ScannerService
    var sessionReady: Bool

    func makeUIViewController(context _: Context) -> LiveCameraPreviewViewController {
        let controller = LiveCameraPreviewViewController()
        controller.scanner = scanner
        controller.sessionReady = sessionReady
        controller.syncPreviewIfNeeded()
        return controller
    }

    func updateUIViewController(_ uiViewController: LiveCameraPreviewViewController, context _: Context) {
        uiViewController.scanner = scanner
        let readyChanged = uiViewController.sessionReady != sessionReady
        uiViewController.sessionReady = sessionReady
        if readyChanged || sessionReady {
            uiViewController.syncPreviewIfNeeded()
        }
    }
}

/// Hosts the scanner's `AVCaptureVideoPreviewLayer` in the view hierarchy.
@MainActor
final class LiveCameraPreviewViewController: UIViewController {
    var scanner: (any ScannerService)?
    var sessionReady = false

    private let previewHost = CameraPreviewRootView()
    private var sessionStartObserver: NSObjectProtocol?

    override func loadView() {
        view = previewHost
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sessionStartObserver = NotificationCenter.default.addObserver(
            forName: .ratioVitaCaptureSessionDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncPreviewIfNeeded()
            }
        }
    }

    deinit {
        if let sessionStartObserver {
            NotificationCenter.default.removeObserver(sessionStartObserver)
        }
    }

    private var isBindingPreview = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncPreviewIfNeeded()
        #if DEBUG
        logPreviewDiagnostics()
        #endif
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncPreviewIfNeeded()
    }

    /// Binds the preview whenever the capture session is running (does not wait on `sessionReady`).
    func syncPreviewIfNeeded() {
        guard !isBindingPreview else { return }
        isBindingPreview = true
        defer { isBindingPreview = false }

        guard let session = scanner?.avCaptureSessionForPreview() else {
            previewHost.detachPreviewLayer()
            return
        }

        guard session.isRunning else {
            if !sessionReady {
                previewHost.detachPreviewLayer()
            }
            return
        }

        if let previewLayer = scanner?.getVideoPreviewLayer() as? AVCaptureVideoPreviewLayer {
            previewHost.attachPreviewLayer(previewLayer)
        } else {
            previewHost.bindCaptureSession(session)
        }
    }

    #if DEBUG
    private func logPreviewDiagnostics() {
        let bounds = previewHost.bounds
        let session = scanner?.avCaptureSessionForPreview()
        let layer = previewHost.attachedPreviewLayer
        print(
            "RatioVita preview: sessionReady=\(sessionReady) viewBounds=\(bounds) "
                + "layerFrame=\(String(describing: layer?.frame)) "
                + "sessionRunning=\(session?.isRunning ?? false) "
                + "layerInHierarchy=\(layer?.superlayer != nil)"
        )
    }
    #endif
}

/// Adds the preview layer as a sublayer (more reliable than `layerClass` overrides in SwiftUI hosts).
final class CameraPreviewRootView: UIView {
    private(set) weak var attachedPreviewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        isOpaque = true
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        if attachedPreviewLayer === layer, layer.superlayer === self.layer {
            finalizePreviewLayerLayout(layer)
            return
        }

        attachedPreviewLayer?.removeFromSuperlayer()
        attachedPreviewLayer = layer
        layer.videoGravity = .resizeAspectFill
        self.layer.insertSublayer(layer, at: 0)
        finalizePreviewLayerLayout(layer)
    }

    func bindCaptureSession(_ session: AVCaptureSession) {
        let layer: AVCaptureVideoPreviewLayer
        if let existing = attachedPreviewLayer {
            layer = existing
        } else {
            let created = AVCaptureVideoPreviewLayer(session: session)
            created.videoGravity = .resizeAspectFill
            self.layer.insertSublayer(created, at: 0)
            attachedPreviewLayer = created
            layer = created
        }

        if layer.session !== session {
            layer.session = session
        }
        finalizePreviewLayerLayout(layer)
    }

    func detachPreviewLayer() {
        attachedPreviewLayer?.removeFromSuperlayer()
        attachedPreviewLayer = nil
    }

    private func finalizePreviewLayerLayout(_ layer: AVCaptureVideoPreviewLayer) {
        updatePreviewFrame(for: layer)
        CameraPreviewLayerConfigurator.apply(to: layer, in: self)
    }

    private func updatePreviewFrame(for layer: AVCaptureVideoPreviewLayer) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        layer.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = attachedPreviewLayer {
            updatePreviewFrame(for: layer)
        }
    }
}

#if os(iOS) || os(visionOS)
enum CameraPreviewLayerConfigurator {
    static func apply(to previewLayer: AVCaptureVideoPreviewLayer, in hostView: UIView) {
        guard let connection = previewLayer.connection else { return }
        connection.isEnabled = true
        if #available(iOS 17.0, visionOS 1.0, *) {
            let angle = previewRotationAngle(for: hostView)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    @available(iOS 17.0, visionOS 1.0, *)
    private static func previewRotationAngle(for hostView: UIView) -> CGFloat {
        guard let orientation = hostView.window?.windowScene?.interfaceOrientation else { return 90 }
        switch orientation {
            case .portrait: return 90
            case .portraitUpsideDown: return 270
            case .landscapeLeft: return 180
            case .landscapeRight: return 0
            default: return 90
        }
    }
}
#endif

#endif

#if os(macOS)
import AppKit
import AVFoundation

struct LiveCameraMultiPageCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let liveScanner: any LiveMultiPageCameraScanning
    let onProcessBatch: @MainActor (_ pageURLs: [URL]) async -> Void

    @ObservedObject private var batch = ReceiptBatchManager.shared
    @State private var isPreparing = true
    @State private var isCapturing = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var liveSessionTornDown = false
    @State private var isPreviewSessionReady = false
    @State private var captureSessionOpened = false

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
                Task { await tearDownLiveSessionIfNeeded(clearBatch: true) }
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
            Text(batch.pageCount == 0 ? "No pages yet" : "\(batch.pageCount) page(s) captured")
                .font(DesignSystem.Typography.caption.weight(.semibold))
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.ratioVitaError)
                    .font(.caption)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(batch.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            ReceiptBatchThumbnailViewMac(thumbnailURL: page.thumbnailURL)
                                .frame(width: 56, height: 72)
                                .clipped()
                            Text("\(index + 1)")
                                .font(.caption2)
                                .padding(2)
                            Button("×") { batch.removePage(at: index) }
                                .buttonStyle(.plain)
                        }
                        .frame(width: 64, height: 80)
                    }
                }
            }
            .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth)
            .frame(height: batch.isEmpty ? 0 : 80)
            .clipped()
        }
    }

    private var macControls: some View {
        HStack {
            Button("Capture page") {
                Task { await snapPhoto() }
            }
            .disabled(isPreparing || isCapturing || isProcessing)
            Button(batch.pageCount > 0 ? "Finish Scan (\(batch.pageCount))" : "Finish Scan") {
                Task { await finishBatch() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(batch.isEmpty || isProcessing)
        }
    }

    @MainActor
    private func tearDownLiveSessionIfNeeded(clearBatch: Bool) async {
        guard !liveSessionTornDown else { return }
        liveSessionTornDown = true
        isPreviewSessionReady = false
        if clearBatch {
            batch.endSession(deleteFiles: true)
        }
        await liveScanner.tearDownLiveCameraSession()
    }

    @MainActor
    private func openSession() async {
        guard !captureSessionOpened else { return }
        captureSessionOpened = true
        isPreparing = true
        defer { isPreparing = false }
        do {
            try batch.beginSession()
            try await liveScanner.prepareLiveCameraSession()
            isPreviewSessionReady = true
        } catch {
            captureSessionOpened = false
            errorMessage = error.ratioVitaUserDescription
            batch.endSession(deleteFiles: true)
        }
    }

    @MainActor
    private func closeSession() async {
        await tearDownLiveSessionIfNeeded(clearBatch: true)
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            let image = try await liveScanner.captureLiveCameraPhoto()
            try batch.appendCapturedImage(image)
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func finishBatch() async {
        guard !batch.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        let urls = batch.pageURLs
        await tearDownLiveSessionIfNeeded(clearBatch: false)
        await onProcessBatch(urls)
        batch.endSession(deleteFiles: true)
        dismiss()
    }
}

private struct ReceiptBatchThumbnailViewMac: View {
    let thumbnailURL: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .task(id: thumbnailURL) {
            image = await Task.detached(priority: .utility) {
                guard let data = try? Data(contentsOf: thumbnailURL, options: [.mappedIfSafe]),
                      let decoded = NSImage(data: data) else { return nil as NSImage? }
                return decoded
            }.value
        }
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

    private var isBindingPreview = false

    override func viewDidLayout() {
        super.viewDidLayout()
        syncPreviewIfNeeded()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        syncPreviewIfNeeded()
    }

    func syncPreviewIfNeeded() {
        guard !isBindingPreview else { return }
        isBindingPreview = true
        defer { isBindingPreview = false }

        guard let session = scanner?.avCaptureSessionForPreview() else {
            previewHost.detachPreviewLayer()
            return
        }

        guard session.isRunning else {
            if !sessionReady {
                previewHost.detachPreviewLayer()
            }
            return
        }

        if let previewLayer = scanner?.getVideoPreviewLayer() as? AVCaptureVideoPreviewLayer {
            previewHost.attachPreviewLayer(previewLayer)
        } else {
            previewHost.bindCaptureSession(session)
        }
    }
}

final class MacCameraPreviewRootView: NSView {
    private(set) weak var attachedPreviewLayer: AVCaptureVideoPreviewLayer?

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

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        if attachedPreviewLayer === layer, layer.superlayer === self.layer {
            updatePreviewFrame(for: layer)
            return
        }

        attachedPreviewLayer?.removeFromSuperlayer()
        attachedPreviewLayer = layer
        layer.videoGravity = .resizeAspectFill
        self.layer?.insertSublayer(layer, at: 0)
        updatePreviewFrame(for: layer)
    }

    func bindCaptureSession(_ session: AVCaptureSession) {
        let layer: AVCaptureVideoPreviewLayer
        if let existing = attachedPreviewLayer {
            layer = existing
        } else {
            let created = AVCaptureVideoPreviewLayer(session: session)
            created.videoGravity = .resizeAspectFill
            self.layer?.insertSublayer(created, at: 0)
            attachedPreviewLayer = created
            layer = created
        }

        if layer.session !== session {
            layer.session = session
        }
        updatePreviewFrame(for: layer)
    }

    func detachPreviewLayer() {
        attachedPreviewLayer?.removeFromSuperlayer()
        attachedPreviewLayer = nil
    }

    private func updatePreviewFrame(for layer: AVCaptureVideoPreviewLayer) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        layer.frame = bounds
    }

    override func layout() {
        super.layout()
        if let layer = attachedPreviewLayer {
            updatePreviewFrame(for: layer)
        }
    }
}
#endif
