import Foundation
import SwiftData

@MainActor
enum ControlledInvitationTree {
    static func generateToken() -> String {
        ConsultantTokenFactory.generateInviteToken()
    }

    @discardableResult
    static func issueInvite(
        context: ModelContext,
        parent: ExpertConsultantProfile,
        childEmail: String,
        department: IndustryDepartmentScope
    ) throws -> InvitationNode? {
        guard parent.tier == .departmentHead, parent.inviteAllocationRemaining > 0 else { return nil }
        let node = InvitationNode(
            parentConsultantID: parent.id,
            childEmail: childEmail,
            department: department
        )
        context.insert(node)
        parent.inviteAllocationRemaining -= 1
        parent.updatedAt = .now
        try context.save()
        return node
    }

    static func activate(
        context: ModelContext,
        token: String,
        profile: ExpertConsultantProfile
    ) throws {
        let descriptor = FetchDescriptor<InvitationNode>()
        let nodes = try context.fetch(descriptor)
        guard let node = nodes.first(where: { $0.singleUseToken == token && !$0.isActivated }) else {
            return
        }
        node.isActivated = true
        profile.parentConsultantID = node.parentConsultantID
        profile.department = IndustryDepartmentScope(rawValue: node.childDepartmentScopeRaw) ?? profile.department
        try context.save()
    }
}
