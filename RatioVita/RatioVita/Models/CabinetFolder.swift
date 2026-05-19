import Foundation
import SwiftData

/// Hierarchical folder under a top-level **cabinet** (`DocumentCabinet` raw value). Sprint D filing surface.
@Model
final class CabinetFolder {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortIndex: Int
    /// Matches `DocumentCabinet.rawValue` (`vehicles`, `equipment`, `tools`).
    var cabinetKindRaw: String
    var parent: CabinetFolder?
    @Relationship(deleteRule: .cascade, inverse: \CabinetFolder.parent) var children: [CabinetFolder]

    init(
        id: UUID = UUID(),
        title: String,
        sortIndex: Int = 0,
        cabinetKindRaw: String,
        parent: CabinetFolder? = nil
    ) {
        self.id = id
        self.title = title
        self.sortIndex = sortIndex
        self.cabinetKindRaw = cabinetKindRaw
        self.parent = parent
        children = []
    }

    @MainActor
    static func ensureRootFoldersSeeded(modelContext: ModelContext) throws {
        for kind in DocumentCabinet.allCases {
            let raw = kind.rawValue
            let fd = FetchDescriptor<CabinetFolder>(sortBy: [SortDescriptor(\.sortIndex)])
            let all = (try? modelContext.fetch(fd)) ?? []
            let hasRoot = all.contains { $0.cabinetKindRaw == raw && $0.parent == nil }
            if !hasRoot {
                modelContext.insert(CabinetFolder(title: kind.title, sortIndex: 0, cabinetKindRaw: raw, parent: nil))
            }
        }
        try modelContext.save()
    }
}
