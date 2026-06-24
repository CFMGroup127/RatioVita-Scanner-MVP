import Foundation

/// Where an agent request originates in the hybrid topology.
enum HybridAgentOrigin: String, Codable, Sendable {
    case ratioVitaEdge = "RatioVitaEdge"
    case vitaLogicExpert = "VitaLogicExpert"
}

/// Active application environment for persona mantle switching.
/// Legacy wire format — prefer `AgentMantle` via `HybridAgentRequest.mantle`.
enum ContextualMantleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case productionMode = "ProductionMode"
    case ventureMode = "VentureMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .productionMode: "Production mode"
        case .ventureMode: "Venture mode"
        }
    }

    var agentMantle: AgentMantle {
        switch self {
        case .productionMode: .production(.empty)
        case .ventureMode: .venture(.empty)
        }
    }

    init(agentMantle: AgentMantle) {
        switch agentMantle {
        case .production: self = .productionMode
        case .venture: self = .ventureMode
        }
    }
}

/// Financial expert unit dispatched by the intelligence engine.
enum FinancialExpertStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case operationalBookkeeper = "OperationalBookkeeper"
    case taxationAuditor = "TaxationAuditor"
    case corporateComptroller = "CorporateComptroller"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .operationalBookkeeper: "Operational bookkeeper"
        case .taxationAuditor: "Taxation auditor"
        case .corporateComptroller: "Corporate comptroller"
        }
    }
}

enum HybridAgentRequestKind: String, Codable, Sendable {
    case financialAnalysis = "FinancialAnalysis"
    case corporateLedgerReview = "CorporateLedgerReview"
    case productionLogistics = "ProductionLogistics"
    case researchBrief = "ResearchBrief"
    case generalExpert = "GeneralExpert"
}

/// Edge → expert broker envelope (local queue + optional Firestore relay).
struct HybridAgentRequest: Codable, Identifiable, Sendable {
    let id: String
    let origin: HybridAgentOrigin
    let kind: HybridAgentRequestKind
    let targetExpertEmail: String?
    let targetExpertName: String?
    let productionPUID: String?
    let productionId: String?
    let sovereignHubRaw: String?
    let mantleRaw: String
    let financialStrategyRaw: String?
    let payloadSummary: String
    let createdAt: Date
    var status: HybridAgentRequestStatus
    var responseSummary: String?

    init(
        id: String = UUID().uuidString,
        origin: HybridAgentOrigin = .ratioVitaEdge,
        kind: HybridAgentRequestKind,
        targetExpertEmail: String? = nil,
        targetExpertName: String? = nil,
        productionPUID: String? = nil,
        productionId: String? = nil,
        sovereignHubRaw: String? = nil,
        mantle: AgentMantle = .production(.empty),
        financialStrategy: FinancialExpertStrategy? = nil,
        payloadSummary: String,
        createdAt: Date = .now,
        status: HybridAgentRequestStatus = .queuedLocal,
        responseSummary: String? = nil
    ) {
        self.id = id
        self.origin = origin
        self.kind = kind
        self.targetExpertEmail = targetExpertEmail
        self.targetExpertName = targetExpertName
        self.productionPUID = productionPUID
        self.productionId = productionId
        self.sovereignHubRaw = sovereignHubRaw
        mantleRaw = Self.encodeMantle(mantle)
        financialStrategyRaw = financialStrategy?.rawValue
        self.payloadSummary = payloadSummary
        self.createdAt = createdAt
        self.status = status
        self.responseSummary = responseSummary
    }

    var mantle: AgentMantle {
        Self.decodeMantle(mantleRaw) ?? .production(.empty)
    }

    private static func encodeMantle(_ mantle: AgentMantle) -> String {
        guard let data = try? JSONEncoder().encode(mantle),
              let json = String(data: data, encoding: .utf8) else {
            return mantle.storageKey
        }
        return json
    }

    private static func decodeMantle(_ raw: String) -> AgentMantle? {
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(AgentMantle.self, from: data) {
            return decoded
        }
        return AgentMantle.from(storageKey: raw)
    }
}

enum HybridAgentRequestStatus: String, Codable, Sendable {
    case queuedLocal = "QueuedLocal"
    case relayedCloud = "RelayedCloud"
    case processingExpert = "ProcessingExpert"
    case completed = "Completed"
    case failed = "Failed"
}

struct FinancialIntelligenceReport: Sendable {
    let strategy: FinancialExpertStrategy
    let findings: [String]
    let warnings: [String]
    let processedAt: Date
}
