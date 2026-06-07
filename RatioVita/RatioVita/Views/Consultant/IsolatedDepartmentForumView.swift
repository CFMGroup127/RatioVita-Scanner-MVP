import SwiftData
import SwiftUI

struct IsolatedDepartmentForumView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: ExpertConsultantProfile

    @Query(sort: \DepartmentForumPost.createdAt, order: .reverse) private var allPosts: [DepartmentForumPost]
    @State private var draft = ""

    private var visiblePosts: [DepartmentForumPost] {
        allPosts.filter { $0.departmentScopeRaw == profile.departmentScopeRaw }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("\(profile.department.displayName) echo chamber") {
                    if visiblePosts.isEmpty {
                        Text("No posts yet — share likes, dislikes, and wish-list items with your dept only.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visiblePosts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.anonymousToken)
                                .font(.caption.monospaced())
                            Text(post.body)
                        }
                    }
                }
            }
            HStack {
                TextField("Private dept note…", text: $draft)
                Button("Post") { post() }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Dept forum")
    }

    private func post() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = DepartmentForumPost(
            department: profile.department,
            anonymousToken: profile.anonymousToken,
            body: trimmed
        )
        modelContext.insert(item)
        try? modelContext.save()
        draft = ""
    }
}
