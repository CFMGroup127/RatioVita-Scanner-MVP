import SwiftData
import SwiftUI

/// Parses machine-oriented tokens embedded in `SovereignAuditLogEntry.detail` (e.g. `rid:` / `mrid:`).
enum SovereignAuditDetailRefs {
    static func receiptID(from detail: String?) -> UUID? {
        guard let detail else { return nil }
        if let id = uuidAfterKey("rid:", in: detail) { return id }
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u = UUID(uuidString: trimmed) { return u }
        if let r = detail.range(of: "receipt ", options: .backwards) {
            let tail = detail[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return UUID(uuidString: tail)
        }
        return nil
    }

    static func merchantRuleID(from detail: String?) -> UUID? {
        uuidAfterKey("mrid:", in: detail ?? "")
    }

    private static func uuidAfterKey(_ key: String, in detail: String) -> UUID? {
        guard let r = detail.range(of: key) else { return nil }
        var tail = String(detail[r.upperBound...])
        if let pipe = tail.firstIndex(of: "|") {
            tail = String(tail[..<pipe])
        }
        let token = tail.split(separator: ";").first.map(String.init) ?? tail
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return UUID(uuidString: cleaned)
    }
}

// MARK: - Merchant rule sidecar

private struct MerchantFilingRuleDetailView: View {
    let ruleID: UUID

    @Query private var rules: [MerchantFilingRule]

    init(ruleID: UUID) {
        self.ruleID = ruleID
        _rules = Query(filter: #Predicate<MerchantFilingRule> { $0.id == ruleID })
    }

    var body: some View {
        Group {
            if let rule = rules.first {
                Form {
                    Section("Rule") {
                        LabeledContent("Merchant contains", value: rule.merchantContainsNormalized)
                        if let li = rule.lineItemContainsNormalized, !li.isEmpty {
                            LabeledContent("Line item contains", value: li)
                        }
                        LabeledContent("Target Arctic prefix", value: rule.targetVaultPathPrefix)
                        LabeledContent("Priority", value: "\(rule.priority)")
                        LabeledContent("Enabled", value: rule.isEnabled ? "Yes" : "No")
                    }
                }
            } else {
                ContentUnavailableView(
                    "Rule not found",
                    systemImage: "slider.horizontal.3",
                    description: Text("It may have been deleted after this audit entry was recorded.")
                )
            }
        }
    }
}

// MARK: - Audit browser (search + split view on regular width)

/// Scrollable **Sovereign audit** trail (`SovereignAuditLogEntry`) with search and split-friendly navigation.
struct SovereignAuditLogListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \SovereignAuditLogEntry.createdAt, order: .reverse) private var entries: [SovereignAuditLogEntry]

    @State private var searchText = ""
    @State private var selection: UUID?

    private var filteredEntries: [SovereignAuditLogEntry] {
        let q = searchText.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { row in
            row.title.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
                || row.kindRaw.lowercased().contains(q)
                || (row.detail ?? "").folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
        }
    }

    private var selectedEntry: SovereignAuditLogEntry? {
        guard let id = selection else { return nil }
        return filteredEntries.first { $0.id == id }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack {
                    listPane
                        .navigationDestination(for: UUID.self) { id in
                            if let row = filteredEntries.first(where: { $0.id == id }) {
                                auditEntryDetailContent(for: row)
                            } else {
                                ContentUnavailableView(
                                    "Entry not found",
                                    systemImage: "shield.lefthalf.filled",
                                    description: Text("It may have been deleted or filtered out of the current search.")
                                )
                            }
                        }
                }
            } else {
                NavigationSplitView {
                    listPane
                } detail: {
                    NavigationStack {
                        detailPane
                    }
                }
            }
        }
    }

    private var listPane: some View {
        Group {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No audit entries yet" : "No matches",
                    systemImage: "shield.lefthalf.filled",
                    description: Text(
                        searchText.isEmpty
                            ? "Folder changes, filing rules, and receipt re-files appear here."
                            : "Try a different search."
                    )
                )
            } else if horizontalSizeClass == .compact {
                List {
                    ForEach(filteredEntries, id: \.id) { row in
                        NavigationLink(value: row.id) {
                            auditRow(row)
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            } else {
                List(selection: $selection) {
                    ForEach(filteredEntries, id: \.id) { row in
                        auditRow(row)
                            .tag(row.id)
                    }
                }
                #if os(macOS)
                .listStyle(.inset(alternatesRowBackgrounds: true))
                #else
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .searchable(text: $searchText, prompt: "Search merchant, title, or detail")
        .navigationTitle("Sovereign audit")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close audit")
                }
            }
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var detailPane: some View {
        if let row = selectedEntry {
            auditEntryDetailContent(for: row)
        } else {
            ContentUnavailableView(
                "Select an entry",
                systemImage: "sidebar.right",
                description: Text("Choose a row to inspect the related receipt or merchant rule.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close audit")
                }
            }
        }
    }

    @ViewBuilder
    private func auditEntryDetailContent(for row: SovereignAuditLogEntry) -> some View {
        let rid = SovereignAuditDetailRefs.receiptID(from: row.detail)
        let mrid = SovereignAuditDetailRefs.merchantRuleID(from: row.detail)
        if let rid {
            ReceiptDetailByIDView(receiptID: rid)
                .navigationTitle(row.title)
        } else if let mrid {
            MerchantFilingRuleDetailView(ruleID: mrid)
                .navigationTitle(row.title)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text(row.title)
                        .font(DesignSystem.Typography.title3)
                    Text(row.createdAt.formatted(date: .complete, time: .shortened))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(row.kindRaw)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                    if let d = row.detail, !d.isEmpty {
                        Text(d)
                            .font(DesignSystem.Typography.body)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Audit detail")
        }
    }

    @ViewBuilder
    private func auditRow(_ row: SovereignAuditLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.title)
                    .font(DesignSystem.Typography.bodyEmphasized)
                Spacer(minLength: 8)
                Text(row.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(row.kindRaw)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            if let d = row.detail, !d.isEmpty {
                Text(d)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaAdaptiveText.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}
