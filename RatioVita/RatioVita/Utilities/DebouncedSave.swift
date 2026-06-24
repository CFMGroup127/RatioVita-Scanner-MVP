import Foundation

/// Coalesces rapid text edits before hitting SwiftData (prevents ghost entity creation per keystroke).
enum DebouncedSave {
    private static var tasks: [String: Task<Void, Never>] = [:]

    /// Default delay: 400 ms.
    static func schedule(
        key: String,
        delayNanoseconds: UInt64 = 400_000_000,
        action: @escaping @MainActor () -> Void
    ) {
        tasks[key]?.cancel()
        tasks[key] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            action()
            tasks[key] = nil
        }
    }
}
