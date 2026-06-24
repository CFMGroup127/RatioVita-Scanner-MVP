import Foundation
import SwiftData

@MainActor
enum ProductionProjectResolver {
    /// Case-insensitive lookup only — safe to call on every keystroke (no insert).
    static func findExisting(title raw: String, modelContext: ModelContext) -> ProductionProject? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let key = trimmed.lowercased()
        let descriptor = FetchDescriptor<ProductionProject>()
        let projects = (try? modelContext.fetch(descriptor)) ?? []
        return projects.first(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        })
    }

    /// Returns an existing project with the same case-insensitive trimmed title, or inserts a new one.
    static func findOrInsert(title raw: String, modelContext: ModelContext) -> ProductionProject {
        if let existing = findExisting(title: raw, modelContext: modelContext) {
            return existing
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = ProductionProject(title: trimmed)
        modelContext.insert(p)
        return p
    }
}
