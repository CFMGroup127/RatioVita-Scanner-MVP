import Foundation
import SwiftData

/// Runs SwiftData reads off the main actor and returns Sendable snapshots only.
enum SwiftDataBackgroundReader {
    static func perform<T: Sendable>(
        container: ModelContainer,
        priority: TaskPriority = .utility,
        _ work: @Sendable @escaping (ModelContext) throws -> T
    ) async throws -> T {
        try await Task.detached(priority: priority) {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return try work(context)
        }.value
    }

    static func perform<T: Sendable>(
        container: ModelContainer,
        priority: TaskPriority = .utility,
        default defaultValue: T,
        _ work: @Sendable @escaping (ModelContext) throws -> T
    ) async -> T {
        (try? await perform(container: container, priority: priority, work)) ?? defaultValue
    }
}
