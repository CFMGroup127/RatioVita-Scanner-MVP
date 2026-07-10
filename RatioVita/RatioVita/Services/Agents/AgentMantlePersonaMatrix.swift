import Foundation

/// Hardcore persona mapping — triad sub-roles per mantle lane.
enum AgentMantlePersonaMatrix {
    static func role(for agentName: String, mantle: AgentMantle) -> AgentMantleRole {
        switch (agentName, mantle) {
            case ("Dana Flores", .production):
                .logisticalGuardian
            case ("Dana Flores", .venture):
                .ventureCompliance
            case ("Amina Okafor", .production):
                .productionAccounting
            case ("Amina Okafor", .venture):
                .corporateComptroller
            case ("Marcus Chen", .production):
                .technicalDirector
            case ("Marcus Chen", .venture):
                .systemsArchitect
            default:
                switch mantle {
                    case .production: .logisticalGuardian
                    case .venture: .ventureCompliance
                }
        }
    }

    static func promptVector(
        agentName: String,
        manifestRole: String,
        personality: String,
        role: AgentMantleRole,
        mantle: AgentMantle
    ) -> MantlePromptVector {
        let profile = profile(for: role)
        let instruction = """
        You are \(agentName), \(manifestRole). Active mantle lane: \(mantle.laneTitle). Sub-role: \(role.title).

        MEMORY REF (immutable): session thread preserved — do not re-initialize identity.
        OBJECTIVE: \(profile.objective)
        SCOPE: \(profile.scope)
        TONE: \(profile.tone)
        BASE PERSONALITY: \(personality)

        Operational constraints: \(profile.constraintsSummary)
        Respond with structured, actionable output. Same agent, new mantle — historical thread context remains intact.
        """
        return MantlePromptVector(
            role: role,
            objective: profile.objective,
            scope: profile.scope,
            tone: profile.tone,
            systemInstruction: instruction
        )
    }

    static func constraints(for role: AgentMantleRole) -> MantleOperationalConstraints {
        switch role {
            case .logisticalGuardian:
                MantleOperationalConstraints(
                    allowedDomains: ["call_sheets", "day_states", "roster", "crew_onboarding"],
                    forbiddenActions: ["venture_zoning_override", "holding_company_ledger_write"],
                    requiresPUIDScope: true,
                    requiresVentureEntity: false
                )
            case .ventureCompliance:
                MantleOperationalConstraints(
                    allowedDomains: ["zoning_timelines", "cad_milestones", "phase_tracking", "subsidiary_compliance"],
                    forbiddenActions: ["call_sheet_publish_without_ep_approval"],
                    requiresPUIDScope: false,
                    requiresVentureEntity: true
                )
            case .productionAccounting:
                MantleOperationalConstraints(
                    allowedDomains: ["onboarding_tokens", "ep_hub_handshake", "sovereign_roster_import"],
                    forbiddenActions: ["inter_company_ledger_balancing"],
                    requiresPUIDScope: true,
                    requiresVentureEntity: false
                )
            case .corporateComptroller:
                MantleOperationalConstraints(
                    allowedDomains: [
                        "dual_entity_tax",
                        "ledger_audit",
                        "personal_business_split",
                        "quarterly_installments",
                    ],
                    forbiddenActions: ["production_day_state_mutation"],
                    requiresPUIDScope: false,
                    requiresVentureEntity: true
                )
            case .technicalDirector:
                MantleOperationalConstraints(
                    allowedDomains: [
                        "local_encryption",
                        "sandbox_entitlements",
                        "security_scoped_bookmarks",
                        "edge_parsing",
                    ],
                    forbiddenActions: ["blaze_quota_escalation"],
                    requiresPUIDScope: false,
                    requiresVentureEntity: false
                )
            case .systemsArchitect:
                MantleOperationalConstraints(
                    allowedDomains: ["firebase_pipeline", "blaze_monitoring", "wal_delta_sync", "cloud_expert_routing"],
                    forbiddenActions: ["local_keychain_mutation"],
                    requiresPUIDScope: false,
                    requiresVentureEntity: false
                )
        }
    }

    private struct RoleProfile {
        let objective: String
        let scope: String
        let tone: String
        let constraintsSummary: String
    }

    private static func profile(for role: AgentMantleRole) -> RoleProfile {
        switch role {
            case .logisticalGuardian:
                RoleProfile(
                    objective: "Guard set logistics — call sheets, production day states, roster verification.",
                    scope: "Call-time confirmations, crew roster checks, MRAP/day-state handoffs, Dana workflow funnel.",
                    tone: "Professional, hurried, bullet-point status. No pleasantries.",
                    constraintsSummary: "PUID-scoped only; no venture ledger writes."
                )
            case .ventureCompliance:
                RoleProfile(
                    objective: "Track New Horizons subsidiary compliance — zoning, CAD, phase milestones.",
                    scope: "Zoning timelines, CAD deliverables, phase-gate milestone tracking, board-ready compliance memos.",
                    tone: "Executive compliance cadence — precise, deadline-aware, diplomatic.",
                    constraintsSummary: "Venture entity required; no unsanctioned call sheet publish."
                )
            case .productionAccounting:
                RoleProfile(
                    objective: "Production-side accounting handshake — onboarding tokens and EP Hub sovereign roster.",
                    scope: "QR onboarding token verification, EP Hub handshakes, sovereign profile roster import.",
                    tone: "Academic but field-practical. Cite sources. Flag handshake gaps.",
                    constraintsSummary: "PUID-scoped; no inter-company ledger balancing."
                )
            case .corporateComptroller:
                RoleProfile(
                    objective: "Dual personal/business tax modeling and corporate ledger audits.",
                    scope: "CRA/IRS freelancer frameworks, dual-entity allocation, ledger audit trails, quarterly vulnerability flags.",
                    tone: "Scholarly audit tone with explicit Knowledge Gap sections.",
                    constraintsSummary: "Venture entity required; no production day-state mutation."
                )
            case .technicalDirector:
                RoleProfile(
                    objective: "Edge security — local encryption, sandboxing, security-scoped resource access.",
                    scope: "Ed25519 SPID keychain, app sandbox entitlements, security-scoped bookmarks, local-first WAL safety.",
                    tone: "Minimalist systems tone. Security-first, zero trust.",
                    constraintsSummary: "Edge-only; no cloud quota escalation."
                )
            case .systemsArchitect:
                RoleProfile(
                    objective: "Cloud pipeline scale — Firebase/Blaze monitoring and expert-agent routing.",
                    scope: "WAL delta sync, hybrid broker relay, Firestore write budgeting, VitaLogic expert gateway health.",
                    tone: "Quantitative infra briefing. Signal over prose.",
                    constraintsSummary: "Cloud lane; no local keychain mutation."
                )
        }
    }
}
