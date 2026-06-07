import Foundation

struct FilmPosition: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let hatRole: OperationalHatRole
    let rankTier: StructuralRankTier

    init(title: String, hatRole: OperationalHatRole, rankTier: StructuralRankTier) {
        id = title
        self.title = title
        self.hatRole = hatRole
        self.rankTier = rankTier
    }
}

struct FilmDepartment: Identifiable, Sendable {
    let id: String
    let name: String
    let industryScope: IndustryDepartmentScope
    let positions: [FilmPosition]

    init(name: String, industryScope: IndustryDepartmentScope, positions: [FilmPosition]) {
        id = name
        self.name = name
        self.industryScope = industryScope
        self.positions = positions
    }
}

/// Isolated department → position maps (Sprint JJJJ). No cross-list pollution.
enum DepartmentHierarchyRegistry {
    static let productionOfficeName = "The Production Office"

    static let departments: [FilmDepartment] = [
        FilmDepartment(
            name: productionOfficeName,
            industryScope: .tadAD,
            positions: [
                FilmPosition(title: "Production Coordinator (PC)", hatRole: .coordinator, rankTier: .administrative),
                FilmPosition(
                    title: "1st Assistant Production Coordinator (1st APC)",
                    hatRole: .coCaptain,
                    rankTier: .departmentHead
                ),
                FilmPosition(
                    title: "2nd Assistant Production Coordinator (2nd APC)",
                    hatRole: .coordinator,
                    rankTier: .departmentHead
                ),
                FilmPosition(
                    title: "Travel / Accommodation Coordinator",
                    hatRole: .coordinator,
                    rankTier: .departmentHead
                ),
                FilmPosition(title: "Script / Story Coordinator", hatRole: .coordinator, rankTier: .departmentHead),
                FilmPosition(
                    title: "Office Production Assistant (Office PA)",
                    hatRole: .coordinator,
                    rankTier: .fieldCrew
                ),
            ]
        ),
        FilmDepartment(
            name: "Assistant Directors (AD)",
            industryScope: .tadAD,
            positions: [
                // TAD = Trailer Assistant Director: operational command voice of basecamp logistics.
                FilmPosition(
                    title: "Trailer Assistant Director (TAD)",
                    hatRole: .coordinator,
                    rankTier: .departmentHead
                ),
                FilmPosition(title: "1st Assistant Director", hatRole: .setSupervisor, rankTier: .departmentHead),
                FilmPosition(title: "2nd Assistant Director", hatRole: .setSupervisor, rankTier: .departmentHead),
                FilmPosition(title: "3rd Assistant Director", hatRole: .setSupervisor, rankTier: .fieldCrew),
                FilmPosition(title: "Set Production Assistant", hatRole: .setSupervisor, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Transportation",
            industryScope: .transport,
            positions: [
                FilmPosition(title: "Transportation Coordinator", hatRole: .coordinator, rankTier: .administrative),
                FilmPosition(title: "Transportation Captain", hatRole: .captain, rankTier: .departmentHead),
                FilmPosition(title: "Transportation Co-Captain", hatRole: .coCaptain, rankTier: .departmentHead),
                FilmPosition(title: "Picture Vehicle Captain", hatRole: .pictureCar, rankTier: .departmentHead),
                FilmPosition(title: "On-Show Driver", hatRole: .driver, rankTier: .fieldCrew),
                FilmPosition(title: "Swamper", hatRole: .swamper, rankTier: .fieldCrew),
                FilmPosition(title: "Cast / Producer Driver", hatRole: .castProducerDriver, rankTier: .fieldCrew),
                FilmPosition(title: "Unit Mover", hatRole: .unitMover, rankTier: .fieldCrew),
                FilmPosition(title: "Camera Truck Driver", hatRole: .driver, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Camera (IATSE 667)",
            industryScope: .cameraDIT,
            positions: [
                FilmPosition(title: "Director of Photography", hatRole: .setSupervisor, rankTier: .departmentHead),
                FilmPosition(title: "Camera Operator", hatRole: .setSupervisor, rankTier: .departmentHead),
                FilmPosition(
                    title: "1st Assistant Cameraperson (Focus Puller)",
                    hatRole: .setSupervisor,
                    rankTier: .departmentHead
                ),
                FilmPosition(
                    title: "2nd Assistant Cameraperson (Clapper/Loader)",
                    hatRole: .driver,
                    rankTier: .fieldCrew
                ),
                FilmPosition(
                    title: "Digital Imaging Technician (DIT)",
                    hatRole: .productionManager,
                    rankTier: .administrative
                ),
                FilmPosition(title: "Camera Trainee", hatRole: .driver, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Costume / Wardrobe",
            industryScope: .costume,
            positions: [
                FilmPosition(title: "Wardrobe Coordinator", hatRole: .coordinator, rankTier: .administrative),
                FilmPosition(title: "Costume Designer", hatRole: .costumeDesignerRemote, rankTier: .departmentHead),
                FilmPosition(
                    title: "Costume Truck Supervisor",
                    hatRole: .costumeTruckSupervisor,
                    rankTier: .departmentHead
                ),
                // Set Swing shares the First Looks viewport with the Costume Truck Supervisor.
                FilmPosition(title: "Set Swing", hatRole: .costumeTruckSupervisor, rankTier: .fieldCrew),
                FilmPosition(title: "On-Set Dresser", hatRole: .costumeTruckSupervisor, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Art / Set Decoration",
            industryScope: .artSetDec,
            positions: [
                FilmPosition(title: "Art Department Coordinator", hatRole: .coordinator, rankTier: .administrative),
                FilmPosition(title: "Set Decorator", hatRole: .setSupervisor, rankTier: .departmentHead),
                FilmPosition(title: "Set Dec PA", hatRole: .setSupervisor, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Locations",
            industryScope: .locations,
            positions: [
                FilmPosition(title: "Locations Manager", hatRole: .locationsManager, rankTier: .administrative),
                FilmPosition(title: "Locations PA", hatRole: .locationsManager, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Production Accounting",
            industryScope: .accounting,
            positions: [
                FilmPosition(title: "Production Manager", hatRole: .productionManager, rankTier: .administrative),
                FilmPosition(title: "Showrunner / Executive Producer", hatRole: .showRunner, rankTier: .administrative),
                FilmPosition(title: "Accounts Payable Clerk", hatRole: .productionManager, rankTier: .fieldCrew),
            ]
        ),
        FilmDepartment(
            name: "Craft Service (IATSE 411)",
            industryScope: .culinaryCraft,
            positions: [
                FilmPosition(title: "Key Craftservice Provider", hatRole: .coCaptain, rankTier: .departmentHead),
                FilmPosition(title: "Assistant Craftservice Provider", hatRole: .coordinator, rankTier: .fieldCrew),
                FilmPosition(title: "Background Craftservice Provider", hatRole: .swamper, rankTier: .fieldCrew),
                // MTO commercial motor-vehicle compliance role (Sprint KKKK).
                FilmPosition(title: "Compliance Driver", hatRole: .driver, rankTier: .fieldCrew),
            ]
        ),
    ]

    static func department(named name: String) -> FilmDepartment? {
        departments.first { $0.name == name }
    }

    static func positions(forDepartmentNamed name: String) -> [FilmPosition] {
        department(named: name)?.positions ?? []
    }

    static func position(title: String, inDepartment departmentName: String) -> FilmPosition? {
        positions(forDepartmentNamed: departmentName).first { $0.title == title }
    }
}
