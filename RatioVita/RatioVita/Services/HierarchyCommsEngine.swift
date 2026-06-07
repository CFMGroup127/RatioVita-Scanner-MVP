import Foundation
import SwiftData

enum SovereignFocusMode: String, Codable, CaseIterable {
    case privateCitizen = "Private"
    case workShift = "Work"
    case corporateExecutive = "Corporate"
    case executiveLockdown = "Executive Lockdown"
}

struct CommsDeliveryDecision: Sendable {
    var shouldDeliver: Bool
    var shouldBypassDND: Bool
    var routeToProxy: Bool
    var reason: String
}

/// Contextual pager — not a generic chat clone. Respects focus + hierarchy.
@MainActor
enum HierarchyCommsEngine {
    static var activeFocusMode: SovereignFocusMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.focusMode),
                  let mode = SovereignFocusMode(rawValue: raw) else { return .workShift }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.focusMode) }
    }

    static var executiveProxyName: String {
        get { UserDefaults.standard.string(forKey: Keys.proxyName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.proxyName) }
    }

    static var userOperationalRole: String {
        get { UserDefaults.standard.string(forKey: Keys.userRole) ?? "Crew" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.userRole) }
    }

    static func evaluate(
        priority: CommPriorityLevel,
        senderRole: String,
        targetDepartment: String?
    ) -> CommsDeliveryDecision {
        let focus = activeFocusMode

        if priority == .callSheetDistribution || priority == .infrastructureCritical {
            return CommsDeliveryDecision(
                shouldDeliver: true,
                shouldBypassDND: true,
                routeToProxy: false,
                reason: "Critical production override (call sheet / infrastructure)."
            )
        }

        if priority == .operationalUrgent,
           senderRole.lowercased().contains("supervisor")
           || senderRole.lowercased().contains("dept")
           || senderRole.lowercased().contains("key")
        {
            return CommsDeliveryDecision(
                shouldDeliver: true,
                shouldBypassDND: focus != .privateCitizen,
                routeToProxy: focus == .executiveLockdown,
                reason: "Supervisor illness / swap override."
            )
        }

        if focus == .executiveLockdown {
            let proxy = executiveProxyName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !proxy.isEmpty {
                return CommsDeliveryDecision(
                    shouldDeliver: false,
                    shouldBypassDND: false,
                    routeToProxy: true,
                    reason: "Routed to executive proxy (\(proxy))."
                )
            }
        }

        if focus == .privateCitizen || focus == .workShift && priority == .standard {
            if focus == .privateCitizen {
                return CommsDeliveryDecision(
                    shouldDeliver: false,
                    shouldBypassDND: false,
                    routeToProxy: false,
                    reason: "Queued — private focus."
                )
            }
        }

        if let dept = targetDepartment,
           !dept.isEmpty,
           focus == .workShift,
           userOperationalRole.lowercased() != dept.lowercased(),
           userOperationalRole != "PM",
           userOperationalRole != "Producer"
        {
            return CommsDeliveryDecision(
                shouldDeliver: false,
                shouldBypassDND: false,
                routeToProxy: false,
                reason: "Department-scoped — not your channel."
            )
        }

        return CommsDeliveryDecision(
            shouldDeliver: true,
            shouldBypassDND: false,
            routeToProxy: false,
            reason: "Standard delivery."
        )
    }

    @discardableResult
    static func ingest(
        context: ModelContext,
        title: String,
        body: String,
        senderRole: String,
        priority: CommPriorityLevel,
        targetDepartment: String? = nil
    ) throws -> CrewCommsNotice {
        let decision = evaluate(
            priority: priority,
            senderRole: senderRole,
            targetDepartment: targetDepartment
        )
        let notice = CrewCommsNotice(
            title: title,
            body: body,
            senderRole: senderRole,
            priority: priority,
            targetDepartment: targetDepartment,
            wasDelivered: decision.shouldDeliver,
            wasQueuedDuringDND: !decision.shouldDeliver
        )
        context.insert(notice)
        try context.save()
        return notice
    }

    private enum Keys {
        static let focusMode = "com.ratiovita.focusMode"
        static let proxyName = "com.ratiovita.executiveProxyName"
        static let userRole = "com.ratiovita.operationalRole"
    }
}
