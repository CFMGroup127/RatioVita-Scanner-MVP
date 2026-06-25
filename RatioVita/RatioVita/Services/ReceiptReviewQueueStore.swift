import Combine
import Foundation
import SwiftData

/// Paginated review-queue access — avoids loading thousands of `Receipt` models on the main actor at launch.
@MainActor
final class ReceiptReviewQueueStore: ObservableObject {
    static let shared = ReceiptReviewQueueStore()

    static let pageSize = 50

    @Published private(set) var totalCount: Int = 0
    @Published private(set) var loadedReceipts: [Receipt] = []
    @Published private(set) var isLoadingPage = false
    @Published private(set) var hasMorePages = true

    private var nextOffset = 0

    private init() {}

    func refreshTotalCount(container: ModelContainer) async {
        let count = await Self.countPending(container: container)
        totalCount = count
        if loadedReceipts.count > totalCount {
            loadedReceipts = Array(loadedReceipts.prefix(totalCount))
        }
        hasMorePages = loadedReceipts.count < totalCount
    }

    func resetAndLoadFirstPage(context: ModelContext, container: ModelContainer) async {
        nextOffset = 0
        loadedReceipts = []
        hasMorePages = true
        await refreshTotalCount(container: container)
        await loadNextPage(context: context, container: container)
    }

    func loadNextPage(context: ModelContext, container: ModelContainer) async {
        guard !isLoadingPage, hasMorePages else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        await Task.yield()

        var descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.pendingHumanReview == true && $0.trashedAt == nil },
            sortBy: [SortDescriptor(\Receipt.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.pageSize
        descriptor.fetchOffset = nextOffset

        guard let page = try? context.fetch(descriptor), !page.isEmpty else {
            hasMorePages = false
            return
        }

        let existing = Set(loadedReceipts.map(\.id))
        let fresh = page.filter { !existing.contains($0.id) }
        loadedReceipts.append(contentsOf: fresh)
        nextOffset += page.count
        hasMorePages = page.count == Self.pageSize && loadedReceipts.count < totalCount

        if totalCount == 0 {
            await refreshTotalCount(container: container)
        }
    }

    /// Applies a mutation across the full pending queue in chunked fetches so the main actor can breathe.
    func mutateAllPending(context: ModelContext, container: ModelContainer, _ mutate: (Receipt) -> Void) async {
        var offset = 0
        while true {
            await Task.yield()
            var descriptor = FetchDescriptor<Receipt>(
                predicate: #Predicate { $0.pendingHumanReview == true && $0.trashedAt == nil },
                sortBy: [SortDescriptor(\Receipt.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            descriptor.fetchOffset = offset
            guard let chunk = try? context.fetch(descriptor), !chunk.isEmpty else { break }
            for receipt in chunk { mutate(receipt) }
            offset += chunk.count
            if chunk.count < 100 { break }
        }
        try? ModelContextMainActorSave.saveThrows(context)
        await resetAndLoadFirstPage(context: context, container: container)
    }

    func fetchAllPending(context: ModelContext) async -> [Receipt] {
        var all: [Receipt] = []
        var offset = 0
        while true {
            await Task.yield()
            var descriptor = FetchDescriptor<Receipt>(
                predicate: #Predicate { $0.pendingHumanReview == true && $0.trashedAt == nil },
                sortBy: [SortDescriptor(\Receipt.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            descriptor.fetchOffset = offset
            guard let chunk = try? context.fetch(descriptor), !chunk.isEmpty else { break }
            all.append(contentsOf: chunk)
            offset += chunk.count
            if chunk.count < 100 { break }
        }
        return all
    }

    nonisolated static func countPending(container: ModelContainer) async -> Int {
        await SwiftDataBackgroundReader.perform(container: container, priority: .utility, default: 0) { context in
            let descriptor = FetchDescriptor<Receipt>(
                predicate: #Predicate { $0.pendingHumanReview == true && $0.trashedAt == nil }
            )
            return try context.fetchCount(descriptor)
        }
    }
}
