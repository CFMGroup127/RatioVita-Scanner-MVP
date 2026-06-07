import Foundation

struct LensCalibrationPreset: Identifiable, Sendable {
    let id: String
    let focalLengthMM: Int
    let wirelessMarkerMeters: [Double]
}

/// 1st AC wireless focus distance markers (Sprint BBBB).
@MainActor
enum LensCalibrationMatrix {
    static let defaultPresets: [LensCalibrationPreset] = [
        LensCalibrationPreset(id: "18A", focalLengthMM: 18, wirelessMarkerMeters: [0.6, 1.2, 2.4, 4.8]),
        LensCalibrationPreset(id: "35S", focalLengthMM: 35, wirelessMarkerMeters: [0.9, 1.8, 3.6, 7.2]),
        LensCalibrationPreset(id: "85A", focalLengthMM: 85, wirelessMarkerMeters: [1.5, 3.0, 6.0, 12.0]),
    ]

    static func activePresetID(for profile: CameraCategoryProfile) -> String? {
        profile == .firstAssistantCamera ? "35S" : nil
    }
}
