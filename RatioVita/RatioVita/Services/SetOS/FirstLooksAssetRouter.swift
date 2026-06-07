import Foundation
import SwiftData

/// Single-action first-look capture → designer / set supervisor feed (Sprint SSS).
@MainActor
enum FirstLooksAssetRouter {
    enum CaptureSessionTag: String, CaseIterable {
        case firstLooksCH1 = "First Looks CH-1"
        case firstLooksCH2 = "First Looks CH-2"
        case blockingCheck = "Blocking check"

        var displayName: String { rawValue }
    }

    static func captureFirstLook(
        context: ModelContext,
        castDisplayID: String,
        sessionTag: CaptureSessionTag,
        truckSupervisorToken: String,
        productionTitle: String,
        continuityAnchor: String = "E104-CH-1",
        hatManifestNote: String? = nil
    ) throws -> CreativeFirstLookSnapshot {
        let snapshot = CreativeFirstLookSnapshot(
            castDisplayID: castDisplayID,
            sessionTag: sessionTag.rawValue,
            truckSupervisorToken: truckSupervisorToken,
            productionTitle: productionTitle,
            continuityAnchor: continuityAnchor
        )
        if let hatManifestNote {
            snapshot.notes = hatManifestNote
        }
        context.insert(snapshot)

        let manifest = hatManifestNote ?? "First look captured for \(castDisplayID). Continuity \(continuityAnchor) unchanged."
        try HierarchyCommsEngine.ingest(
            context: context,
            title: "First look · \(castDisplayID)",
            body: "\(sessionTag.rawValue): \(manifest)",
            senderRole: truckSupervisorToken,
            priority: .standard
        )
        try context.save()
        return snapshot
    }

    static func recentFeed(
        context: ModelContext,
        productionTitle: String? = nil,
        limit: Int = 40
    ) throws -> [CreativeFirstLookSnapshot] {
        let descriptor = FetchDescriptor<CreativeFirstLookSnapshot>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        if let productionTitle, !productionTitle.isEmpty {
            return Array(all.filter { $0.productionTitle == productionTitle }.prefix(limit))
        }
        return Array(all.prefix(limit))
    }
}
