import Foundation
import SwiftData

/// A single calendar-relevant work day extracted from a time report / payroll-style document.
@Model
final class WorkSession {
    var id: UUID
    var sortIndex: Int
    var workDate: Date
    var productionTitle: String?
    var productionProject: ProductionProject?
    var departmentOrCategory: String?
    var notes: String?

    /// Owning receipt for this session. Plain optional: `@Relationship` + inverse lives on `Receipt.workSessions`.
    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        workDate: Date = .now,
        productionTitle: String? = nil,
        productionProject: ProductionProject? = nil,
        departmentOrCategory: String? = nil,
        notes: String? = nil,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.workDate = workDate
        self.productionTitle = productionTitle
        self.productionProject = productionProject
        self.departmentOrCategory = departmentOrCategory
        self.notes = notes
        self.receipt = receipt
    }
}
