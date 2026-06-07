import Foundation
import SwiftData

struct LegalTermCard: Identifiable, Sendable {
    let id: Int
    let title: String
    let body: String
}

/// Card-by-card NDA / NCA gate before consultant modules unlock.
@MainActor
enum LegalShieldGatekeeper {
    static let standardTerms: [LegalTermCard] = [
        LegalTermCard(
            id: 1,
            title: "Non-Disclosure",
            body: """
            You agree not to disclose RatioVita interface layouts, workflow logic, transport matrices, \
            accounting protocols, or cross-venture gastronomy networks to any third party, including \
            family, peers, or competing vendors, during and after your consultancy.
            """
        ),
        LegalTermCard(
            id: 2,
            title: "Non-Compete",
            body: """
            For twenty-four (24) months you will not develop, advise, or invest in software that \
            substantially replicates production logistics, crew payroll automation, or encrypted \
            departmental comms as implemented in RatioVita.
            """
        ),
        LegalTermCard(
            id: 3,
            title: "Department isolation",
            body: """
            You will access only modules scoped to your assigned department. Attempts to export code, \
            capture unauthorized screenshots, or view unrelated financial ledgers may trigger immediate \
            sandbox revocation.
            """
        ),
        LegalTermCard(
            id: 4,
            title: "Pay data protection",
            body: """
            Negotiated rates and deal memo data are stored under cryptographic anonymization for testing. \
            Your legal identity is severed from the active sandbox ledger visible to other consultants.
            """
        ),
    ]

    static func isLegalComplete(profile: ExpertConsultantProfile?) -> Bool {
        guard let profile else { return false }
        return !profile.legalTokenHash.isEmpty && profile.isAuthorizedForTesting
    }

    static func completeLegalShield(
        context: ModelContext,
        profile: ExpertConsultantProfile,
        initialsPerTerm: [Int: String]
    ) throws {
        guard initialsPerTerm.count >= standardTerms.count else { return }
        let payload = initialsPerTerm
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        profile.legalTokenHash = "LEGAL-\(payload.hashValue)-\(UUID().uuidString.prefix(8))"
        profile.isAuthorizedForTesting = true
        profile.updatedAt = .now
        ConsultantSessionManager.shared.setActiveProfileID(profile.id)
        try context.save()
    }
}
