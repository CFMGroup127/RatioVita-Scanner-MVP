import Foundation

/// Canonical tax / GL category strings used by agents and filters.
enum TaxCategoryCatalog {
    static let preIncorporationRD = "PreIncorporation_RD"

    static func isPreIncorporationRD(_ raw: String?) -> Bool {
        raw?.trimmingCharacters(in: .whitespacesAndNewlines) == preIncorporationRD
    }

    /// Heuristic: RatioVita / VitaLogic dev spend before formal registration.
    static func suggestFromCorpus(_ corpus: String) -> String? {
        let c = corpus.lowercased()
        let rdMarkers = [
            "ratiovita", "vitalogic", "cursor", "openai", "anthropic", "gemini",
            "xcode", "github", "swiftdata", "development", "software subscription",
            "saas", "api key", "cloud hosting",
        ]
        guard rdMarkers.contains(where: { c.contains($0) }) else { return nil }
        if c.contains("incorporation") || c.contains("articles") { return nil }
        return preIncorporationRD
    }
}
