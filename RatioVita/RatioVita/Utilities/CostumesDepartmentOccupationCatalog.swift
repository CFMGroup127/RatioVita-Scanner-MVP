import Foundation

/// IATSE Local 873 **Costumes** classifications (2024–28 feature wage schedule reference).
enum CostumesDepartmentOccupationCatalog {
    static let otherTitle = "Other (type custom)"

    static let supervisory: [String] = [
        "Costume Designer",
        "Assistant Costume Designer",
        "Costume Supervisor",
        "Costume Set Supervisor",
        "Assistant Costume Set Supervisor",
        "Set Swing",
    ]

    static let onSetAndBackground: [String] = [
        "On-Set Costumer / Wardrobe Assistant",
        "Costume Dresser / Sewer",
        "Background Costumer",
    ]

    static let administrativeAndPrep: [String] = [
        "Costume Buyer",
        "Cutter / Pattern Maker",
        "Costume Tracker / Budget Coder",
        "Truck Supervisor",
    ]

    static var allTitles: [String] {
        supervisory + onSetAndBackground + administrativeAndPrep
    }

    static var pickerOptions: [String] {
        allTitles + [otherTitle]
    }

    static func isKnownTitle(_ title: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return allTitles.contains { $0.caseInsensitiveCompare(t) == .orderedSame }
    }
}

/// Department → occupation picker options for production rate tiers.
enum ProductionDepartmentOccupationCatalog {
    static let departmentPresets: [String] = [
        "Costumes",
        "Transport",
        "Performers",
        "Locations",
        "Assistant Directors",
        "Set Dec",
        "Grip & Electric",
        "Hair & Makeup",
        "Production Office",
    ]

    static let otherDepartment = "Other (type custom)"

    static var allDepartments: [String] {
        departmentPresets + [otherDepartment]
    }

    static func occupations(for department: String) -> [String] {
        let trimmed = department.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
            case "Costumes":
                return CostumesDepartmentOccupationCatalog.pickerOptions
            case "Transport":
                return transportTitles + [CostumesDepartmentOccupationCatalog.otherTitle]
            case "Performers":
                return performerTitles + [CostumesDepartmentOccupationCatalog.otherTitle]
            case "Locations":
                return locationTitles + [CostumesDepartmentOccupationCatalog.otherTitle]
            case "Assistant Directors":
                return adTitles + [CostumesDepartmentOccupationCatalog.otherTitle]
            default:
                return IATSE873PositionCatalog.pickerOptions
        }
    }

    private static let transportTitles: [String] = [
        "Transportation Coordinator",
        "Truck Supervisor",
        "Driver",
        "Loader",
    ]

    private static let performerTitles: [String] = [
        "BG Tanker Driver (Special Skills)",
        "BG Skateboard Stunt",
        "Background Performer",
        "Stand-In",
    ]

    private static let locationTitles: [String] = [
        "Set PA / Lockup Support",
        "Location Manager",
        "Assistant Location Manager",
    ]

    private static let adTitles: [String] = [
        "3rd AD / Background Marshall",
        "2nd AD",
        "1st AD",
        "Key 2nd AD",
    ]
}
