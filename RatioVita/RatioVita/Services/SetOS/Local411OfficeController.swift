import Foundation

/// IATSE Local 411 caucus router (Sprint CCCC).
@MainActor
enum Local411OfficeController {
    static func caucus(for hat: OperationalHatRole) -> CaucusClassification {
        switch hat {
            case .coordinator, .productionManager, .showRunner:
                .productionCoordinator
            case .driver, .swamper:
                .officePA
            case .coCaptain:
                .craftserviceProvider
            case .captain, .pictureCar:
                .honeywagonOperator
            default:
                .productionCoordinator
        }
    }

    static func panelTitle(for caucus: CaucusClassification) -> String {
        switch caucus {
            case .productionCoordinator: "411 · Office backbone"
            case .officePA: "411 · Office PA runs"
            case .craftserviceProvider: "411 · Craft service mesh"
            case .honeywagonOperator: "411 · Honeywagon fleet"
        }
    }
}
