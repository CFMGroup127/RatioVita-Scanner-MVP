//
//  CameraPermissions.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

#if os(iOS) || os(visionOS) || os(macOS)
import AVFoundation
import Foundation

enum CameraPermissions {
    static func isCameraAvailable() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }
        #if os(macOS)
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external,
        ]
        #else
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
        ]
        #endif
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        return !discovery.devices.isEmpty
    }

    static func getCameraPermissionStatus() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .authorized
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .unavailable
        }
    }

    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
            case .authorized:
                return true
            case .denied, .restricted:
                return false
            case .notDetermined:
                return await AVCaptureDevice.requestAccess(for: .video)
            @unknown default:
                return false
        }
    }
}
#endif
