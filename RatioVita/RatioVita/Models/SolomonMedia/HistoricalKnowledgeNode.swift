import Foundation
import SwiftData

/// Book / research assembly node — raw chat logs, etymology, timelines tagged for cross-reference.
@Model
final class HistoricalKnowledgeNode {
    @Attribute(.unique) var id: UUID
    var title: String
    var bodyMarkdown: String
    /// Comma-separated tags (e.g. DNA, CouncilOfNicaea, HumanSexuality).
    var tagsRaw: String
    var governanceTypeRaw: String = ContentGovernanceType.forensicHistory.rawValue
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        bodyMarkdown: String,
        tags: [String] = [],
        governance: ContentGovernanceType = .forensicHistory,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        tagsRaw = Self.encodeTags(tags)
        governanceTypeRaw = governance.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension HistoricalKnowledgeNode {
    var governance: ContentGovernanceType {
        get { ContentGovernanceType(rawValue: governanceTypeRaw) ?? .forensicHistory }
        set { governanceTypeRaw = newValue.rawValue }
    }

    var tags: [String] {
        get { Self.decodeTags(tagsRaw) }
        set { tagsRaw = Self.encodeTags(newValue) }
    }

    static func encodeTags(_ tags: [String]) -> String {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            .joined(separator: ",")
    }

    static func decodeTags(_ raw: String) -> [String] {
        raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
