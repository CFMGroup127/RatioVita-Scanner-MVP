import Combine
import Foundation

/// Offline practice workspace before a live production license (Sprint IIII).
@MainActor
final class SandboxEnvironmentController: ObservableObject {
    static let shared = SandboxEnvironmentController()

    @Published private(set) var isActive = false
    @Published private(set) var statusMessage: String?

    private init() {}

    func activate(departmentName: String, positionTitle: String) {
        isActive = true
        statusMessage =
            "Sandbox active · \(departmentName) · \(positionTitle). Mock scripts, timecards, and fleet tools — no live server."
    }

    func deactivate() {
        isActive = false
        statusMessage = nil
    }

    func mockWatermarkedScriptRevision(color: String = "Pink") -> String {
        "SANDBOX-\(color.uppercased())-REV-\(Int(Date().timeIntervalSince1970))"
    }
}
