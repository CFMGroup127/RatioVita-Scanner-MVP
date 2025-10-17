import Testing
import SwiftData
@testable import RatioVita

@Suite("Sample seeding creates receipts and images")
struct SampleSeedTests {
    @Test
    func seedInMemoryContainer() async throws {
        let schema = Schema([Receipt.self, ReceiptImage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try #require(try? ModelContainer(for: schema, configurations: [config]))
        let context = container.mainContext

        SampleSeed.insertSamples(into: context, options: .init())

        let fetch = FetchDescriptor<Receipt>()
        let receipts = try context.fetch(fetch)
        #expect(!receipts.isEmpty, "Expected seeded receipts")

        let totalImages = receipts.flatMap { $0.images }.count
        #expect(totalImages > 0, "Expected at least one image across receipts")
    }
}
