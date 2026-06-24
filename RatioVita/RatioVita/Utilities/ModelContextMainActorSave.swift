import SwiftData

/// Persists SwiftData on the main actor (avoids “Publishing changes from background threads”).
enum ModelContextMainActorSave {
    @MainActor
    static func save(_ context: ModelContext) {
        Task {
            await saveDeferred(context)
        }
    }

    @MainActor
    static func saveThrows(_ context: ModelContext) throws {
        try context.save()
    }

    /// Yields one frame before persisting so SwiftUI transitions are not blocked by WAL checkpoints.
    @MainActor
    static func saveDeferred(_ context: ModelContext) async {
        await Task.yield()
        try? context.save()
    }
}
