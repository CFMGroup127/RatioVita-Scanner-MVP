import Foundation

/// Financial bucket for contextual ledger routing (maps 1:1 with `SovereignHubKind`).
enum SovereignLedger: String, CaseIterable, Codable, Sendable, Identifiable {
    case personal
    case venture
    case production

    var id: String { rawValue }

    init(hub: SovereignHubKind) {
        switch hub {
            case .personal: self = .personal
            case .ventures: self = .venture
            case .production: self = .production
        }
    }

    var hubKind: SovereignHubKind {
        switch self {
            case .personal: .personal
            case .venture: .ventures
            case .production: .production
        }
    }

    var displayName: String {
        switch self {
            case .personal: "Personal"
            case .venture: "Venture"
            case .production: "Production"
        }
    }

    /// Gemini / prompt label for the active hub at capture time.
    var promptContextLabel: String {
        switch self {
            case .personal: "Personal Hub (household & personal ledger)"
            case .venture: "Ventures Hub (side ventures & property)"
            case .production: "Production Mode (show isolation & PUID)"
        }
    }

    static func fromStored(_ raw: String?) -> SovereignLedger? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let exact = SovereignLedger(rawValue: raw) { return exact }
        if raw == SovereignHubKind.ventures.rawValue { return .venture }
        if raw == SovereignHubKind.production.rawValue { return .production }
        if raw == SovereignHubKind.personal.rawValue { return .personal }
        return nil
    }

    /// Normalizes Gemini `suggestedCategory` strings.
    static func fromSuggestedCategory(_ raw: String?) -> SovereignLedger? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !t.isEmpty else {
            return nil
        }
        if t.contains("production") || t.contains("show") || t.contains("crew") { return .production }
        if t.contains("venture") || t.contains("business") || t.contains("corporate") { return .venture }
        if t.contains("personal") || t.contains("household") { return .personal }
        return SovereignLedger(rawValue: t)
    }
}
