import Foundation

/// How Labor Sentinel applies OT / turnaround rules for a show.
enum ProductionAutomationGovernance: String, CaseIterable, Codable, Hashable, Identifiable {
    case unionIATSE873 = "union_iatse_873"
    case unionIATSE411 = "union_iatse_411"
    /// Flat / favor deals — logs hours and contract overages without union penalty alarms.
    case customNonUnion = "custom_non_union"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
            case .unionIATSE873: "Union — IATSE 873"
            case .unionIATSE411: "Union — IATSE 411 Chef"
            case .customNonUnion: "Non-union / custom contract"
        }
    }

    var shortTitle: String {
        switch self {
            case .unionIATSE873: "873"
            case .unionIATSE411: "411"
            case .customNonUnion: "Custom"
        }
    }
}
