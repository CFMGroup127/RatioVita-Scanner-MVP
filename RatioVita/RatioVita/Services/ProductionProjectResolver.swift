import Foundation
import SwiftData

@MainActor
enum ProductionProjectResolver {
    /// Returns an existing project with the same case-insensitive trimmed title, or inserts a new one.
    static func findOrInsert(title raw: String, modelContext: ModelContext) -> ProductionProject {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.lowercased()
        let descriptor = FetchDescriptor<ProductionProject>()
        let projects = (try? modelContext.fetch(descriptor)) ?? []
        if let existing = projects.first(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }) {
            return existing
        }
        let p = ProductionProject(title: trimmed)
        modelContext.insert(p)
        return p
    }
}
