import Combine
import Foundation

/// Brand / artwork clearance tracking (Sprint CCCC).
@MainActor
final class LegalClearanceEngine: ObservableObject {
    static let shared = LegalClearanceEngine()

    @Published private(set) var assets: [LegalClearanceAsset] = []

    private init() {
        assets = [
            LegalClearanceAsset(
                id: UUID(),
                brandName: "Energy drink (background)",
                assetContextDescription: "Set dec · kitchen counter",
                isLegalClearanceApproved: false,
                boundDepartmentHat: "SET_DEC"
            ),
        ]
    }

    func ingestFromDepartment(brandName: String, departmentHat: String, context: String) {
        let asset = LegalClearanceAsset(
            id: UUID(),
            brandName: brandName,
            assetContextDescription: context,
            isLegalClearanceApproved: false,
            boundDepartmentHat: departmentHat
        )
        assets.insert(asset, at: 0)
    }

    func setApproval(id: UUID, approved: Bool) {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }
        assets[index].isLegalClearanceApproved = approved
    }
}
