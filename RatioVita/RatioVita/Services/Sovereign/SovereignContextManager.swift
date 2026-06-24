import Combine
import Foundation
import SwiftUI

/// Top-level hub the crew member is operating in — personal, venture, or isolated production mode.
enum SovereignHubKind: String, CaseIterable, Identifiable, Codable {
    case personal
    case ventures
    case production

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Personal Hub"
        case .ventures: "Ventures Hub"
        case .production: "Production Mode"
        }
    }

    var systemImage: String {
        switch self {
        case .personal: "person.crop.circle.fill"
        case .ventures: "building.2.fill"
        case .production: "film.stack.fill"
        }
    }
}

/// Global sovereign context — drives UI isolation and default routing for triage / receipts.
@MainActor
final class SovereignContextManager: ObservableObject {
    static let shared = SovereignContextManager()

    @Published private(set) var activeHub: SovereignHubKind = .personal
    @Published private(set) var activeVentureEntityID: UUID?
    @Published private(set) var activeProductionID: UUID?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.hub),
           let hub = SovereignHubKind(rawValue: raw)
        {
            activeHub = hub
        }
        if let ventureRaw = UserDefaults.standard.string(forKey: Keys.ventureID),
           let ventureID = UUID(uuidString: ventureRaw)
        {
            activeVentureEntityID = ventureID
        }
        if let productionRaw = UserDefaults.standard.string(forKey: Keys.productionID),
           let productionID = UUID(uuidString: productionRaw)
        {
            activeProductionID = productionID
        } else if let legacy = UserDefaults.standard.string(forKey: Keys.legacyForensicProductionID),
                  let productionID = UUID(uuidString: legacy)
        {
            activeProductionID = productionID
        }
    }

    /// Deferred activation — call after `FirebaseApp.configure()` completes (RatioVitaApp launch task).
    func completeDeferredLaunchSetup() {
        guard !didCompleteDeferredLaunchSetup else { return }
        didCompleteDeferredLaunchSetup = true
        applyMantleContext()
        setupFirebaseListenersIfReady()
    }

    private var didCompleteDeferredLaunchSetup = false

    var displaySubtitle: String {
        switch activeHub {
        case .personal:
            "Subscriptions · household · personal gifts"
        case .ventures:
            activeVentureEntityID == nil
                ? "Side ventures · property · New Horizons"
                : "Venture entity selected"
        case .production:
            activeProductionID == nil
                ? "Pick an active show for isolation"
                : "Strict production containment"
        }
    }

    /// Production token used for data isolation when in production mode.
    var isolationProductionID: UUID? {
        activeHub == .production ? activeProductionID : nil
    }

    /// Maps sovereign hub to agent mantle lane (Production vs Venture).
    var activeAgentMantle: AgentMantle {
        switch activeHub {
        case .production:
            return .production(ProductionContext(
                productionID: activeProductionID?.uuidString,
                activeDayState: nil
            ))
        case .ventures:
            return .venture(VentureContext(
                ventureEntityID: activeVentureEntityID?.uuidString,
                subsidiaryLabel: "New Horizons"
            ))
        case .personal:
            return .venture(VentureContext(subsidiaryLabel: "Personal Hub"))
        }
    }

    /// Deprecated alias — use `activeAgentMantle`.
    var activeContextualMantle: ContextualMantleKind {
        ContextualMantleKind(agentMantle: activeAgentMantle)
    }

    func switchToPersonalHub() {
        activeHub = .personal
        persist()
        setupFirebaseListenersIfReady()
    }

    func switchToVenturesHub(ventureEntityID: UUID? = nil) {
        activeHub = .ventures
        activeVentureEntityID = ventureEntityID
        persist()
        setupFirebaseListenersIfReady()
    }

    func switchToProductionMode(productionID: UUID) {
        activeHub = .production
        activeProductionID = productionID
        UserDefaults.standard.set(productionID.uuidString, forKey: Keys.legacyForensicProductionID)
        persist()
        setupFirebaseListenersIfReady()
    }

    /// Returns true when `productionProjectID` belongs in the current isolation scope.
    func matchesIsolationScope(productionProjectID: UUID?) -> Bool {
        guard activeHub == .production, let isolation = activeProductionID else { return true }
        guard let productionProjectID else { return false }
        return productionProjectID == isolation
    }

    func matchesIsolationScope(receipt: Receipt) -> Bool {
        matchesIsolationScope(productionProjectID: receipt.productionProject?.id)
    }

    func receiptIsVisible(_ receipt: Receipt) -> Bool {
        SovereignScopeFilter.receiptIsVisible(receipt, context: self)
    }

    func scopedDisplayTotal(for receipt: Receipt) -> Decimal {
        SovereignScopeFilter.scopedDisplayTotal(for: receipt, context: self)
    }

    var isolationScopeLabel: String {
        switch activeHub {
        case .personal:
            "Personal ledger only"
        case .ventures:
            activeVentureEntityID == nil
                ? "All venture ledgers"
                : "Single venture ledger"
        case .production:
            activeProductionID == nil
                ? "Production ledger (unpinned)"
                : "Production isolation active"
        }
    }

    private func persist() {
        UserDefaults.standard.set(activeHub.rawValue, forKey: Keys.hub)
        if let venture = activeVentureEntityID {
            UserDefaults.standard.set(venture.uuidString, forKey: Keys.ventureID)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.ventureID)
        }
        if let production = activeProductionID {
            UserDefaults.standard.set(production.uuidString, forKey: Keys.productionID)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.productionID)
        }
        AgentMantleRegistry.shared.applyApplicationContext(
            activeAgentMantle,
            productionID: activeProductionID,
            ventureEntityID: activeVentureEntityID,
            activeHub: activeHub
        )
    }

    private func applyMantleContext() {
        AgentMantleRegistry.shared.applyApplicationContext(
            activeAgentMantle,
            productionID: activeProductionID,
            ventureEntityID: activeVentureEntityID,
            activeHub: activeHub
        )
    }

    /// Starts Firestore logistical listeners only after Firebase bootstrap is ready.
    func setupFirebaseListenersIfReady() {
        RatioVitaFirebaseBootstrap.ensureConfigured()
        guard RatioVitaFirebaseBootstrap.isConfigured else { return }
        syncLogisticsCoordinator()
    }

    private func syncLogisticsCoordinator() {
        let productionIdString = activeProductionID?.uuidString ?? ""
        ProductionLogisticsLiveCoordinator.shared.syncActiveProduction(productionId: productionIdString)
    }

    private enum Keys {
        static let hub = "com.ratiovita.sovereign.activeHub"
        static let ventureID = "com.ratiovita.sovereign.activeVentureEntityID"
        static let productionID = "com.ratiovita.sovereign.activeProductionID"
        static let legacyForensicProductionID = "forensicActiveProductionID"
    }
}
