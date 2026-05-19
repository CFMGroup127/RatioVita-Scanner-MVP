import CoreData
import SwiftData
import SwiftUI

/// SwiftData’s CloudKit stack is built on **Core Data**’s `NSPersistentCloudKitContainer`. Remote imports post
/// `NSPersistentStoreRemoteChange`; processing pending changes nudges `@Query` / bound models without requiring
/// pull-to-refresh. (Core Data’s `automaticallyMergesChangesFromParent` is handled inside SwiftData’s store
/// coordinator for CloudKit configurations — this is the companion **UI coherence** hook.)
struct SwiftDataRemoteSyncRefreshModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                Task { @MainActor in
                    modelContext.processPendingChanges()
                }
            }
    }
}

extension View {
    /// Call on the root app surface that already has `modelContext` in the environment (e.g. under `ContentView`).
    func swiftDataCloudKitRemoteMergeRefresh() -> some View {
        modifier(SwiftDataRemoteSyncRefreshModifier())
    }
}
