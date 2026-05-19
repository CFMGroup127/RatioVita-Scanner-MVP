import Foundation

/// Standard **IATSE 873** costume / catering / transport classifications for pickers (user can still choose Other).
enum IATSE873PositionCatalog {
    static let otherTitle = "Other (type custom)"

    static let standardTitles: [String] = [
        "Truck Supervisor",
        "Transportation Coordinator",
        "Driver",
        "Set Swing",
        "Set Costumer",
        "Truck Costumer",
        "Costume Coordinator",
        "Assistant Costume Coordinator",
        "Wardrobe Assistant",
        "Catering Assistant",
        "Head Caterer",
        "Chef",
        "Craft Services",
        "Loader",
        "Set PA",
        "Production Assistant",
    ]

    static var pickerOptions: [String] {
        standardTitles + [otherTitle]
    }
}
