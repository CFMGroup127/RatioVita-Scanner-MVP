import SwiftData
import SwiftUI

private let largeRenameLinkedRowThreshold = 40

/// Edit a canonical production / show title; all linked receipts and work sessions see the update immediately.
struct ProductionProjectRenameView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var project: ProductionProject

    @State private var titleField: String = ""
    @State private var showLargeRenameConfirm = false
    @State private var isApplyingRename = false
    @State private var bulkProgressDone: Int = 0
    @State private var bulkProgressTotal: Int = 0

    private var linkedRowCount: Int {
        project.receipts.count + project.workSessions.count
    }

    var body: some View {
        Form {
            Section {
                TextField("Show / project title", text: $titleField)
                Text(
                    "Linked: \(project.receipts.count) receipt(s), \(project.workSessions.count) work session(s). Saving updates this title everywhere."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Section {
                if isApplyingRename {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ProgressView(value: Double(bulkProgressDone), total: Double(max(bulkProgressTotal, 1)))
                        Text("Updating linked rows… \(bulkProgressDone) / \(bulkProgressTotal)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    }
                    .padding(.vertical, 4)
                }
                Button("Save title") {
                    let trimmed = titleField.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if linkedRowCount >= largeRenameLinkedRowThreshold {
                        showLargeRenameConfirm = true
                    } else {
                        Task { await applyTitle(trimmed) }
                    }
                }
                .disabled(titleField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isApplyingRename)
            }
        }
        .navigationTitle("Rename project")
        .onAppear {
            titleField = project.title
        }
        .confirmationDialog(
            "Update \(linkedRowCount) linked rows?",
            isPresented: $showLargeRenameConfirm,
            titleVisibility: .visible
        ) {
            Button("Update all") {
                let trimmed = titleField.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await applyTitle(trimmed) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This project is linked to many receipts and work sessions. RatioVita will refresh denormalized titles in batches."
            )
        }
    }

    @MainActor
    private func applyTitle(_ trimmed: String) async {
        guard !trimmed.isEmpty else { return }
        isApplyingRename = true
        bulkProgressTotal = max(project.workSessions.count, 1)
        bulkProgressDone = 0
        project.title = trimmed
        project.updatedAt = .now
        let sessions = project.workSessions
        for (i, ws) in sessions.enumerated() {
            ws.productionTitle = trimmed
            bulkProgressDone = i + 1
            if i % 12 == 0 {
                try? modelContext.save()
                await Task.yield()
            }
        }
        try? modelContext.save()
        isApplyingRename = false
        bulkProgressDone = bulkProgressTotal
    }
}
