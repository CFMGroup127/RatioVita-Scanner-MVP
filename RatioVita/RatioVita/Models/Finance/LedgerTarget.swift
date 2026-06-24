import Foundation

/// Venture / personal ledger destination for a dispersed line item.
enum LedgerTargetKind: String, Codable, CaseIterable, Sendable {
    case personal
    case cateringCompany
    case property
    case wardrobeKit
    case gift
}

/// Codable assignment for API / agent payloads (not persisted as JSON on SwiftData rows).
struct LedgerTargetAssignment: Equatable, Sendable {
    var kind: LedgerTargetKind
    /// When `kind == .personal`, hooks into regimen / keto tracking.
    var regimenTrackingEnabled: Bool
    /// Catering corp or property asset id when applicable.
    var ventureEntityID: UUID?

    static func personal(regimen: Bool = false) -> LedgerTargetAssignment {
        LedgerTargetAssignment(kind: .personal, regimenTrackingEnabled: regimen, ventureEntityID: nil)
    }

    static func cateringCompany(id: UUID) -> LedgerTargetAssignment {
        LedgerTargetAssignment(kind: .cateringCompany, regimenTrackingEnabled: false, ventureEntityID: id)
    }

    static func property(id: UUID) -> LedgerTargetAssignment {
        LedgerTargetAssignment(kind: .property, regimenTrackingEnabled: false, ventureEntityID: id)
    }

    static var wardrobeKit: LedgerTargetAssignment {
        LedgerTargetAssignment(kind: .wardrobeKit, regimenTrackingEnabled: false, ventureEntityID: nil)
    }

    static var gift: LedgerTargetAssignment {
        LedgerTargetAssignment(kind: .gift, regimenTrackingEnabled: false, ventureEntityID: nil)
    }

    var displaySummary: String {
        switch kind {
        case .personal:
            regimenTrackingEnabled ? "Personal / Regimen" : "Personal"
        case .cateringCompany:
            "Catering" + (ventureEntityID.map { " (\($0.uuidString.prefix(8)))" } ?? "")
        case .property:
            "Property" + (ventureEntityID.map { " (\($0.uuidString.prefix(8)))" } ?? "")
        case .wardrobeKit:
            "Wardrobe Kit"
        case .gift:
            "Gift"
        }
    }
}
