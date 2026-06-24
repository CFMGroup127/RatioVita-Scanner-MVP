import Foundation

// MARK: - Stable session memory (never rewritten on mantle switch)

/// Immutable pointer to the agent's primary thread / memory doc — preserved across mantle swaps.
struct AgentMemoryReference: Codable, Sendable, Equatable {
    let sessionThreadID: String
    let memoryDocumentRef: String

    init(agentEmail: String) {
        sessionThreadID = "thread-\(agentEmail.lowercased())"
        memoryDocumentRef = "memory://agents/\(agentEmail.lowercased())/primary"
    }
}

// MARK: - Adaptive agent protocol

/// Existing agent instance that swaps operational mantles without session teardown.
protocol AdaptiveAgent: AnyObject, Identifiable {
    var activeIdentifier: String { get }
    var displayName: String { get }
    var basePersonality: String { get }
    var baseMemoryReference: AgentMemoryReference { get }
    var runningMantle: AgentMantle { get }
    var activeRole: AgentMantleRole { get }
    var systemPromptVector: MantlePromptVector { get }
    var operationalConstraints: MantleOperationalConstraints { get }

    func applyMantle(_ mantle: AgentMantle) throws -> MantleTransitionResult
}

// MARK: - Manifest-backed adaptive agent (Dana / Amina / Marcus triad)

@MainActor
final class ManifestAdaptiveAgent: AdaptiveAgent {
    let manifestName: String
    let manifestRole: String
    let activeIdentifier: String
    let displayName: String
    let basePersonality: String
    let baseMemoryReference: AgentMemoryReference

    private(set) var runningMantle: AgentMantle
    private(set) var activeRole: AgentMantleRole
    private(set) var systemPromptVector: MantlePromptVector
    private(set) var operationalConstraints: MantleOperationalConstraints

    var id: String { activeIdentifier }

    init(
        name: String,
        role: String,
        email: String,
        personality: String,
        initialMantle: AgentMantle = .production(.empty)
    ) {
        manifestName = name
        manifestRole = role
        activeIdentifier = email
        displayName = name
        basePersonality = personality
        baseMemoryReference = AgentMemoryReference(agentEmail: email)
        runningMantle = initialMantle

        let mapped = AgentMantlePersonaMatrix.role(for: name, mantle: initialMantle)
        activeRole = mapped
        systemPromptVector = AgentMantlePersonaMatrix.promptVector(
            agentName: name,
            manifestRole: role,
            personality: personality,
            role: mapped,
            mantle: initialMantle
        )
        operationalConstraints = AgentMantlePersonaMatrix.constraints(for: mapped)
    }

    @discardableResult
    func applyMantle(_ mantle: AgentMantle) throws -> MantleTransitionResult {
        let previousRole = activeRole
        let newRole = AgentMantlePersonaMatrix.role(for: displayName, mantle: mantle)
        let vector = AgentMantlePersonaMatrix.promptVector(
            agentName: displayName,
            manifestRole: manifestRole,
            personality: basePersonality,
            role: newRole,
            mantle: mantle
        )
        guard !vector.systemInstruction.isEmpty else {
            throw AgentMantleRegistryError.emptyPromptVector(activeIdentifier)
        }

        runningMantle = mantle
        activeRole = newRole
        systemPromptVector = vector
        operationalConstraints = AgentMantlePersonaMatrix.constraints(for: newRole)

        return MantleTransitionResult(
            agentIdentifier: activeIdentifier,
            previousRole: previousRole,
            newRole: newRole,
            memoryReferencePreserved: true,
            systemInstruction: vector.systemInstruction
        )
    }
}
