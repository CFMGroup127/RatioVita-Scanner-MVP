import Foundation

/// Fuzzy match for OCR-typo vendor names (e.g. "Bespoke Graft… Tnc.") against owned corporations.
enum CorporateIdentityMatcher {
    private static let stopWords: Set<String> = [
        "inc", "ltd", "llc", "corp", "corporation", "services", "service", "and", "the", "of", "company", "co",
    ]

    static func matchesOwnedCorporation(
        contactName: String,
        companyName: String?,
        ownedCorporations: [BusinessEntity]
    ) -> BusinessEntity? {
        let corpus = normalizedCorpus(contactName, companyName)
        guard !corpus.isEmpty else { return nil }

        for entity in ownedCorporations where entity.isOwnedCorporation {
            if matches(entity: entity, corpus: corpus) {
                return entity
            }
        }
        return nil
    }

    static func matchesInternalOwner(
        contactName: String,
        companyName: String?,
        ownerLegalName: String,
        nameVariances: [String]
    ) -> Bool {
        let corpus = normalizedCorpus(contactName, companyName)
        guard !corpus.isEmpty else { return false }

        var candidates = [ownerLegalName] + nameVariances
        candidates.append(contentsOf: ownerLegalName.split(separator: " ").map(String.init))

        for raw in candidates {
            let key = RegistryEntityPolarity.normalizedToken(raw)
            guard key.count >= 3 else { continue }
            if corpus.contains(key) { return true }
        }
        return false
    }

    private static func matches(entity: BusinessEntity, corpus: String) -> Bool {
        let legalKey = RegistryEntityPolarity.normalizedToken(entity.legalName)
        if !legalKey.isEmpty, corpus.contains(legalKey) { return true }

        let keywords = significantKeywords(from: entity.legalName)
        guard !keywords.isEmpty else { return false }

        let hits = keywords.filter { corpus.contains($0) }
        if keywords.contains("celebrity"), corpus.contains("celebrity") { return true }
        if keywords.contains("bespoke"), corpus.contains("bespoke") { return true }

        let required = min(2, keywords.count)
        return hits.count >= required
    }

    private static func significantKeywords(from legalName: String) -> [String] {
        legalName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                guard token.count >= 4 else { return false }
                return !stopWords.contains(token)
            }
    }

    private static func normalizedCorpus(_ name: String, _ company: String?) -> String {
        RegistryEntityPolarity.normalizedToken("\(name) \(company ?? "")")
    }
}
