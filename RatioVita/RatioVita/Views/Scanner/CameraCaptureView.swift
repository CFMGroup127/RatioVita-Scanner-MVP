//
//  CameraCaptureView.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(iOS)
/// SwiftUI wrapper for camera capture interface (iOS)
struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanComplete: (ScanResult) async -> Void

    init(onScanComplete: @escaping (ScanResult) async -> Void) {
        self.onScanComplete = onScanComplete
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Camera Capture")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Camera functionality coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Close") {
                    Task {
                        // Create a mock ScanResult for now
                        let mockResult = ScanResult(
                            scannedPages: [],
                            extractedData: ExtractedData(),
                            processingMetadata: ProcessingMetadata(
                                processingTime: 0.0,
                                ocrEnabled: false,
                                compressionEnabled: false,
                                compressionQuality: 0.8,
                                imageProcessingSteps: []
                            )
                        )
                        await onScanComplete(mockResult)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // iOS-only placement
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("CameraCaptureView (iOS)") {
    CameraCaptureView { scanResult in
        print("Scan completed: \(scanResult)")
    }
}
#else
/// macOS stub to keep references compiling if accidentally used.
/// You can replace this with a real macOS implementation later if desired.
struct CameraCaptureView: View {
    let onScanComplete: (ScanResult) async -> Void

    init(onScanComplete: @escaping (ScanResult) async -> Void) {
        self.onScanComplete = onScanComplete
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Camera is not available on macOS")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("CameraCaptureView (macOS)") {
    CameraCaptureView { _ in }
}
#endif