import SwiftData
import SwiftUI

struct ConsultantInvitationCockpitView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: ExpertConsultantProfile

    @Query(sort: \InvitationNode.createdAt, order: .reverse) private var invites: [InvitationNode]
    @State private var childEmail = ""
    @State private var statusMessage: String?

    private var myInvites: [InvitationNode] {
        invites.filter { $0.parentConsultantID == profile.id }
    }

    var body: some View {
        Form {
            Section("Invite allocation") {
                Text("Remaining tokens: \(profile.inviteAllocationRemaining)")
                TextField("Subordinate email", text: $childEmail)
                    .textContentType(.emailAddress)
                Button("Issue single-use invite") { issue() }
                    .disabled(profile.inviteAllocationRemaining <= 0 || childEmail.isEmpty)
            }
            Section("Child nodes") {
                if myInvites.isEmpty {
                    Text("No invites issued yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(myInvites) { node in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.childEmail)
                        Text(node.singleUseToken)
                            .font(.caption.monospaced())
                        Text(node.isActivated ? "Activated" : "Pending")
                            .font(.caption2)
                    }
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
        }
        .navigationTitle("Invite tree")
    }

    private func issue() {
        do {
            if let node = try ControlledInvitationTree.issueInvite(
                context: modelContext,
                parent: profile,
                childEmail: childEmail,
                department: profile.department
            ) {
                statusMessage = "Issued token \(node.singleUseToken)"
                childEmail = ""
            } else {
                statusMessage = "No allocation remaining or not a department head."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
