import Foundation
import SwiftData

/// Storyboard / deployment-script row: timestamp + audio spec + visual prompt (chat §9 wireframe table).
@Model
final class MediaProductionBeat {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var timestampStartSeconds: Double
    var timestampEndSeconds: Double?
    var audioSpec: String
    var visualPrompt: String
    var governanceTypeRaw: String = ContentGovernanceType.horizontalSolomon.rawValue
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var mediaAsset: MediaAsset?

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        timestampStartSeconds: Double,
        timestampEndSeconds: Double? = nil,
        audioSpec: String,
        visualPrompt: String,
        governance: ContentGovernanceType = .horizontalSolomon,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mediaAsset: MediaAsset? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.timestampStartSeconds = timestampStartSeconds
        self.timestampEndSeconds = timestampEndSeconds
        self.audioSpec = audioSpec
        self.visualPrompt = visualPrompt
        governanceTypeRaw = governance.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mediaAsset = mediaAsset
    }
}

extension MediaProductionBeat {
    var governance: ContentGovernanceType {
        get { ContentGovernanceType(rawValue: governanceTypeRaw) ?? .horizontalSolomon }
        set { governanceTypeRaw = newValue.rawValue }
    }

    var timestampLabel: String {
        let end = timestampEndSeconds.map { String(format: "%.0f", $0) } ?? "…"
        return String(format: "%.0f–%@s", timestampStartSeconds, end)
    }
}
