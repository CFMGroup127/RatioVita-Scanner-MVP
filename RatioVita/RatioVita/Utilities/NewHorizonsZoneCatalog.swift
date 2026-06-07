import Foundation

/// Physical zone tags for 176 Yonge Street — New Horizons production hub.
enum NewHorizonsZoneCatalog {
    static let vaultPrefix = "New-Horizons/176-Yonge"

    static let zones: [String] = [
        "PATH Concourse — Commuter Engine",
        "Ground Floor — 52-Week Soundstage",
        "Floor 2 — Marché & Lanai",
        "Floor 3 — Banquet Deck",
        "Floors 4–5 — Loft / Courtyard",
        "Floor 6 Roof Shelf — Greenhouse Terrace",
        "Floors 8–9 — Prep Labs & Talent Lofts",
        "Floor 10 — Executive Guild & Broadcast",
        "Level 11 — Pit & Hearth Rooftop",
        "Rebel Hub — Fleet Dispatch",
        "Unassigned Zone",
    ]

    /// Legacy short IDs for receipts / CapEx filters.
    static let zoneShortIDs: [String: String] = [
        "Z-PATH": "PATH Concourse — Commuter Engine",
        "Z-GF": "Ground Floor — 52-Week Soundstage",
        "Z-02": "Floor 2 — Marché & Lanai",
        "Z-03": "Floor 3 — Banquet Deck",
        "Z-RC": "Level 11 — Pit & Hearth Rooftop",
        "Z-SC": "Speakers Corner — Broadcast Booth",
        "Z-AT": "Main Atrium — Heritage Shell",
        "Z-LD": "Loading Dock — Fleet Intake",
        "Z-RB": "Rebel Hub — Fleet Dispatch",
    ]

    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
