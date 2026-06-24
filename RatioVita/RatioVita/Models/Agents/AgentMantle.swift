import Foundation

// MARK: - Application context payloads

/// Set-logistics / production isolation context (RatioVita edge).
struct ProductionContext: Codable, Sendable, Equatable {
    var productionPUID: String?
    var productionID: String?
    var activeDayState: String?

    static let empty = ProductionContext()
}

/// New Horizons / subsidiary corporate context (VitaLogic expert lane).
struct VentureContext: Codable, Sendable, Equatable {
    var ventureEntityID: String?
    var subsidiaryLabel: String?
    var phaseMilestone: String?

    static let empty = VentureContext()
}

// MARK: - Mantle enum

/// Rigid two-lane mantle — production set ops vs venture corporate ops.
enum AgentMantle: Sendable, Equatable {
    case production(ProductionContext)
    case venture(VentureContext)
}

extension AgentMantle: Codable {
    private enum CodingKeys: String, CodingKey {
        case lane, production, venture
    }

    private enum Lane: String, Codable {
        case production, venture
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Lane.self, forKey: .lane) {
        case .production:
            self = .production(try container.decode(ProductionContext.self, forKey: .production))
        case .venture:
            self = .venture(try container.decode(VentureContext.self, forKey: .venture))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .production(let context):
            try container.encode(Lane.production, forKey: .lane)
            try container.encode(context, forKey: .production)
        case .venture(let context):
            try container.encode(Lane.venture, forKey: .lane)
            try container.encode(context, forKey: .venture)
        }
    }
}

extension AgentMantle {
    var laneTitle: String {
        switch self {
        case .production: "Production"
        case .venture: "Venture"
        }
    }

    var storageKey: String {
        switch self {
        case .production: "production"
        case .venture: "venture"
        }
    }

    static func from(
        storageKey: String,
        production: ProductionContext = .empty,
        venture: VentureContext = .empty
    ) -> AgentMantle {
        storageKey == "venture" ? .venture(venture) : .production(production)
    }
}

// MARK: - Persona sub-role matrix

/// Hard-mapped operational sub-role worn under an `AgentMantle` lane.
enum AgentMantleRole: String, Codable, Sendable, CaseIterable {
    case logisticalGuardian = "LogisticalGuardian"
    case ventureCompliance = "VentureCompliance"
    case productionAccounting = "ProductionAccounting"
    case corporateComptroller = "CorporateComptroller"
    case technicalDirector = "TechnicalDirector"
    case systemsArchitect = "SystemsArchitect"

    var title: String { rawValue }
}

// MARK: - Prompt vector + constraints

struct MantlePromptVector: Sendable, Equatable {
    let role: AgentMantleRole
    let objective: String
    let scope: String
    let tone: String
    let systemInstruction: String
}

struct MantleOperationalConstraints: Sendable, Equatable {
    let allowedDomains: [String]
    let forbiddenActions: [String]
    let requiresPUIDScope: Bool
    let requiresVentureEntity: Bool
}

struct MantleTransitionResult: Sendable {
    let agentIdentifier: String
    let previousRole: AgentMantleRole
    let newRole: AgentMantleRole
    let memoryReferencePreserved: Bool
    let systemInstruction: String
}

enum AgentMantleRegistryError: Error, Sendable {
    case agentNotRegistered(String)
    case invalidTransition(from: AgentMantleRole, to: AgentMantleRole)
    case emptyPromptVector(String)
}
