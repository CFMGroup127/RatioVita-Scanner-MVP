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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ReceiptLiveCameraPreviewRepresentable(scanner: liveScanner)
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
                    Task { await liveScanner.tearDownLiveCameraSession() }
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
                            Image(uiImage: page.image)
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
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: buffer.isEmpty ? 0 : 88)
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
    private func openSession() async {
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }
        do {
            try await liveScanner.prepareLiveCameraSession()
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func closeSession() async {
        await liveScanner.tearDownLiveCameraSession()
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }
        do {
            let image = try await liveScanner.captureLiveCameraPhoto()
            buffer.append(image)
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
        await liveScanner.tearDownLiveCameraSession()
        await onProcessBatch(batch)
        dismiss()
    }
}

private struct ReceiptLiveCameraPreviewRepresentable: UIViewRepresentable {
    let scanner: any ScannerService

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = PreviewHostView()
        view.backgroundColor = .black
        context.coordinator.attachPreview(from: scanner, to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layoutPreview(in: uiView)
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?

        func attachPreview(from scanner: any ScannerService, to view: UIView) {
            guard let layer = scanner.getVideoPreviewLayer() as? AVCaptureVideoPreviewLayer else { return }
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
            if layer.superlayer !== view.layer {
                view.layer.insertSublayer(layer, at: 0)
            }
            layoutPreview(in: view)
        }

        func layoutPreview(in view: UIView) {
            previewLayer?.frame = view.bounds
        }
    }

    final class PreviewHostView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { sub in
                if sub is AVCaptureVideoPreviewLayer {
                    sub.frame = bounds
                }
            }
        }
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ReceiptLiveCameraPreviewRepresentableMac(scanner: liveScanner)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    macThumbnailStrip
                    macControls
                }
                .padding(DesignSystem.Spacing.md)

                if isPreparing || isProcessing {
                    ProgressView(isProcessing ? "Processing batch…" : "Starting camera…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
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
                Task { await liveScanner.tearDownLiveCameraSession() }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
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
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(buffer.pages.enumerated()), id: \.element.id) { index, page in
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: page.image)
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
                    }
                }
            }
            .frame(height: buffer.isEmpty ? 0 : 80)
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
    private func openSession() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            try await liveScanner.prepareLiveCameraSession()
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }

    @MainActor
    private func closeSession() async {
        await liveScanner.tearDownLiveCameraSession()
        dismiss()
    }

    @MainActor
    private func snapPhoto() async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            buffer.append(try await liveScanner.captureLiveCameraPhoto())
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
        await liveScanner.tearDownLiveCameraSession()
        await onProcessBatch(batch)
        dismiss()
    }
}

private struct ReceiptLiveCameraPreviewRepresentableMac: NSViewRepresentable {
    let scanner: any ScannerService

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        if let layer = scanner.getVideoPreviewLayer() as? AVCaptureVideoPreviewLayer {
            layer.frame = view.bounds
            view.layer?.addSublayer(layer)
            context.coordinator.previewLayer = layer
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.previewLayer?.frame = nsView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
#endif
