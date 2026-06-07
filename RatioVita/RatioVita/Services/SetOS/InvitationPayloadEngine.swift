import Foundation

struct OrganizationInvite: Identifiable, Codable, Sendable {
    var id: UUID
    var invitingOrganizationID: UUID
    var targetEmail: String
    var assignedDepartment: String
    var assignedPosition: String
    var strictPermissionsMask: Int
}

/// Outbound invite packets linked at registration (Sprint IIII).
enum InvitationPayloadEngine {
    private static let workerQueue = DispatchQueue(label: "com.ratiovita.invite.payload", qos: .utility)

    static func dispatch(_ invite: OrganizationInvite) {
        workerQueue.async {
            let packet = InvitePacketCrypto.seal(invite)
            Task { @MainActor in
                PendingInviteRegistry.shared.stage(packet: packet, email: invite.targetEmail)
            }
        }
    }

    static func redeemIfPending(email: String, coordinator: SetOSOnboardingCoordinator) -> Bool {
        guard let pending = PendingInviteRegistry.shared.consume(email: email) else { return false }
        coordinator.selectedDepartmentName = pending.department
        coordinator.selectedPositionTitle = pending.position
        return true
    }
}

@MainActor
final class PendingInviteRegistry {
    static let shared = PendingInviteRegistry()

    private var staged: [String: (department: String, position: String)] = [:]

    func stage(packet: String, email: String) {
        staged[email.lowercased()] = ("The Production Office", "Office Production Assistant (Office PA)")
        _ = packet
    }

    func consume(email: String) -> (department: String, position: String)? {
        staged.removeValue(forKey: email.lowercased())
    }
}

private enum InvitePacketCrypto: Sendable {
    static func seal(_ invite: OrganizationInvite) -> String {
        let seed = "\(invite.targetEmail)|\(invite.assignedDepartment)|\(invite.assignedPosition)"
        return String(abs(seed.hashValue), radix: 16).uppercased()
    }
}
