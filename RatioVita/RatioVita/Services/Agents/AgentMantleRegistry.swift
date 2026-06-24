import Combine
import Foundation

/// Strict state machine — rewrites prompt vectors + constraints; never tears down session memory.
@MainActor
final class AgentMantleRegistry: ObservableObject {
    static let shared = AgentMantleRegistry()

    @Published private(set) var activeApplicationMantle: AgentMantle = .production(.empty)
    @Published private(set) var lastTransition: MantleTransitionResult?

    private var agents: [String: ManifestAdaptiveAgent] = [:]

    private init() {
        bootstrapTriad()
    }

    // MARK: - Registration

    func register(_ agent: ManifestAdaptiveAgent) {
        agents[agent.activeIdentifier] = agent
    }

    func agent(for identifier: String) -> ManifestAdaptiveAgent? {
        agents[identifier]
    }

    var triadAgents: [ManifestAdaptiveAgent] {
        AgentMantlePersonaMatrix.triadEmails.compactMap { agents[$0] }
    }

    // MARK: - State machine

    /// Switch a single agent's mantle — preserves `baseMemoryReference`.
    @discardableResult
    func switchMantle(for identifier: String, to mantle: AgentMantle) throws -> MantleTransitionResult {
        guard let agent = agents[identifier] else {
            throw AgentMantleRegistryError.agentNotRegistered(identifier)
        }
        let result = try agent.applyMantle(mantle)
        assert(result.memoryReferencePreserved, "Mantle switch must preserve base memory reference")
        assert(agent.baseMemoryReference == AgentMemoryReference(agentEmail: identifier), "Memory ref pointer mutated")
        lastTransition = result
        return result
    }

    /// Application context switch — rewrites all triad agents atomically.
    func applyApplicationContext(
        _ mantle: AgentMantle,
        productionID: UUID? = nil,
        ventureEntityID: UUID? = nil,
        activeHub: SovereignHubKind? = nil
    ) {
        activeApplicationMantle = mantle
        UserDefaults.standard.set(mantle.storageKey, forKey: Self.applicationMantleKey)

        for email in AgentMantlePersonaMatrix.triadEmails {
            _ = try? switchMantle(
                for: email,
                to: enriched(
                    mantle,
                    productionID: productionID,
                    ventureEntityID: ventureEntityID,
                    activeHub: activeHub
                )
            )
        }
    }

    func restoreApplicationMantle(
        productionContext: ProductionContext = .empty,
        ventureContext: VentureContext = .empty
    ) {
        let key = UserDefaults.standard.string(forKey: Self.applicationMantleKey) ?? "production"
        let mantle = AgentMantle.from(
            storageKey: key,
            production: productionContext,
            venture: ventureContext
        )
        applyApplicationContext(mantle)
    }

    func systemInstruction(for identifier: String) -> String? {
        agents[identifier]?.systemPromptVector.systemInstruction
    }

    func systemInstruction(forName name: String) -> String? {
        guard let email = AgentMantlePersonaMatrix.triadEmails.first(where: {
            agents[$0]?.displayName == name
        }) else {
            return agents.values.first(where: { $0.displayName == name })?.systemPromptVector.systemInstruction
        }
        return agents[email]?.systemPromptVector.systemInstruction
    }

    // MARK: - Bootstrap

    private func bootstrapTriad() {
        for entry in AgentMantlePersonaMatrix.triadEntries {
            register(ManifestAdaptiveAgent(
                name: entry.name,
                role: entry.role,
                email: entry.email,
                personality: entry.personality,
                initialMantle: activeApplicationMantle
            ))
        }
    }

    private func enriched(
        _ mantle: AgentMantle,
        productionID: UUID?,
        ventureEntityID: UUID?,
        activeHub: SovereignHubKind?
    ) -> AgentMantle {
        switch mantle {
        case .production(var ctx):
            if ctx.productionID == nil {
                ctx.productionID = productionID?.uuidString
            }
            return .production(ctx)
        case .venture(var ctx):
            if ctx.ventureEntityID == nil {
                ctx.ventureEntityID = ventureEntityID?.uuidString
            }
            if ctx.subsidiaryLabel == nil, activeHub == .ventures {
                ctx.subsidiaryLabel = "New Horizons"
            }
            return .venture(ctx)
        }
    }

    private static let applicationMantleKey = "com.ratiovita.agentMantle.applicationLane"
}

extension AgentMantlePersonaMatrix {
    struct TriadEntry {
        let name: String
        let role: String
        let email: String
        let personality: String
    }

    static let triadEntries: [TriadEntry] = [
        TriadEntry(
            name: "Dana Flores",
            role: "Chief of Staff",
            email: "dana.flores@ratiovita.com",
            personality: "Precise, diplomatic, handles all meeting minutes"
        ),
        TriadEntry(
            name: "Amina Okafor",
            role: "Research Lead",
            email: "amina.okafor@ratiovita.com",
            personality: "Academic tone, long-form Memory docs"
        ),
        TriadEntry(
            name: "Marcus Chen",
            role: "Lead Analyst",
            email: "marcus.chen@ratiovita.com",
            personality: "Data-driven, concise, focused on KPIs"
        ),
    ]

    static let triadEmails: [String] = triadEntries.map(\.email)
}
