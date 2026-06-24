import Foundation
import SwiftData

/// Destination entity for cross-hub triage routing.
enum SovereignEntityDestination: Equatable, Identifiable {
    case personalHub
    case venture(BusinessEntity)
    case production(ProductionProject)

    var id: String {
        switch self {
        case .personalHub: "personal"
        case let .venture(entity): "venture-\(entity.id.uuidString)"
        case let .production(project): "production-\(project.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .personalHub: "Personal Hub"
        case let .venture(entity): entity.legalName
        case let .production(project): project.title
        }
    }

    var systemImage: String {
        switch self {
        case .personalHub: "person.crop.circle"
        case .venture: "building.2"
        case .production: "film.stack"
        }
    }
}

enum CrossEntityReallocationService {

    static func destinations(
        ventures: [BusinessEntity],
        productions: [ProductionProject]
    ) -> [SovereignEntityDestination] {
        var list: [SovereignEntityDestination] = [.personalHub]
        list += ventures.map { .venture($0) }
        list += productions.map { .production($0) }
        return list
    }

    static func apply(
        destination: SovereignEntityDestination,
        to receipt: Receipt,
        lineIDs: [UUID]? = nil,
        modelContext: ModelContext
    ) {
        let targetLines = filteredLines(receipt: receipt, lineIDs: lineIDs)

        switch destination {
        case .personalHub:
            for line in targetLines {
                line.allocationIsPersonal = true
                line.allocatedBusinessEntity = nil
                line.allocatedProductionProject = nil
            }
            if lineIDs == nil {
                receipt.productionProject = nil
            }
        case let .venture(entity):
            for line in targetLines {
                line.allocationIsPersonal = false
                line.allocatedBusinessEntity = entity
                line.allocatedProductionProject = nil
            }
            if lineIDs == nil {
                receipt.productionProject = nil
            }
        case let .production(project):
            for line in targetLines {
                line.allocationIsPersonal = false
                line.allocatedBusinessEntity = project.businessEntity
                line.allocatedProductionProject = project
            }
            if lineIDs == nil {
                receipt.productionProject = project
            }
        }

        CrossEntityTriageEngine.refreshTriageState(for: receipt)
        try? modelContext.save()
    }

    static func destinationLabel(for line: ReceiptLineItem) -> String {
        if line.allocationIsPersonal { return "Personal Hub" }
        if let project = line.allocatedProductionProject { return project.title }
        if let entity = line.allocatedBusinessEntity { return entity.legalName }
        return "Unrouted"
    }

    private static func filteredLines(receipt: Receipt, lineIDs: [UUID]?) -> [ReceiptLineItem] {
        let sorted = receipt.lineItems.sorted { $0.sortIndex < $1.sortIndex }
        guard let lineIDs, !lineIDs.isEmpty else { return sorted }
        return sorted.filter { lineIDs.contains($0.id) }
    }
}
