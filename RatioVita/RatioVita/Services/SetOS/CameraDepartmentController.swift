import Foundation

/// IATSE 667 camera department rank layouts (Sprint BBBB).
@MainActor
enum CameraDepartmentController {
    static func profile(for hat: OperationalHatRole) -> CameraCategoryProfile {
        switch hat {
            case .productionManager, .showRunner:
                .digitalImagingTechnician
            case .coordinator:
                .unitPublicist
            default:
                .secondAssistantCamera
        }
    }

    static func rankTier(for profile: CameraCategoryProfile) -> StructuralRankTier {
        switch profile {
            case .secondAssistantCamera:
                .fieldCrew
            case .directorOfPhotography, .cameraOperator, .firstAssistantCamera:
                .departmentHead
            case .digitalImagingTechnician, .unitPublicist:
                .administrative
        }
    }

    static func consoleSummary(profile: CameraCategoryProfile) -> String {
        switch profile {
            case .secondAssistantCamera:
                "Slate · media magazines · battery bay"
            case .firstAssistantCamera:
                "Wireless lens calibration · multi-cam focus map"
            case .digitalImagingTechnician:
                "Checksum ledger · LUT match · drive lock"
            case .directorOfPhotography:
                "Look continuity · crane / drone clearance"
            case .cameraOperator:
                "Head telemetry · operator path grid"
            case .unitPublicist:
                "EPK clearance · likeness wrap tokens"
        }
    }
}
