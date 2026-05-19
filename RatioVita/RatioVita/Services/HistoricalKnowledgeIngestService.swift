import Foundation
import SwiftData

/// Ingests pasted research / chat logs into tagged `HistoricalKnowledgeNode` rows.
@MainActor
enum HistoricalKnowledgeIngestService {
    struct IngestResult: Sendable {
        var node: HistoricalKnowledgeNode
        var parsedTags: [String]
    }

    /// Parses `#Tag` tokens from the body and merges with explicit tags.
    static func ingest(
        title: String,
        bodyMarkdown: String,
        extraTags: [String] = [],
        governance: ContentGovernanceType = .forensicHistory,
        context: ModelContext
    ) throws -> IngestResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else {
            throw IngestError.emptyPayload
        }

        let hashTags = parseHashTags(in: trimmedBody)
        let merged = Array(Set(extraTags + hashTags)).sorted()

        let node = HistoricalKnowledgeNode(
            title: trimmedTitle,
            bodyMarkdown: trimmedBody,
            tags: merged,
            governance: governance
        )
        context.insert(node)
        try context.save()
        return IngestResult(node: node, parsedTags: merged)
    }

    private static func parseHashTags(in text: String) -> [String] {
        let pattern = #"#([A-Za-z][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    enum IngestError: LocalizedError {
        case emptyPayload

        var errorDescription: String? {
            switch self {
                case .emptyPayload: "Title and body are required."
            }
        }
    }
}
