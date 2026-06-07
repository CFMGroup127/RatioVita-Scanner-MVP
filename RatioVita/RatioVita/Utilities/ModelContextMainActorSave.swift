import SwiftData

/// Persists SwiftData on the main actor (avoids “Publishing changes from background threads”).
enum ModelContextMainActorSave {
    @MainActor
    static func save(_ context: ModelContext) {
        try? context.save()
    }

    @MainActor
    static func saveThrows(_ context: ModelContext) throws {
        try context.save()
    }
}
