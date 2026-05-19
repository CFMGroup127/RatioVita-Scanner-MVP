import SwiftData
import SwiftUI

// MARK: - Library drill-down (merchant → year → month)

enum ArcticVaultLibraryPhase: Equatable, Hashable {
    case vendorRoot
    case merchantYears(merchantKey: String, displayMerchant: String)
    case merchantYear(merchantKey: String, displayMerchant: String, year: Int)
    case merchantYearMonth(merchantKey: String, displayMerchant: String, year: Int, monthSymbol: String)

    var breadcrumbTitles: [String] {
        switch self {
            case .vendorRoot:
                ["Arctic Vault"]
            case let .merchantYears(_, display):
                ["Arctic Vault", display]
            case let .merchantYear(_, display, y):
                ["Arctic Vault", display, String(y)]
            case let .merchantYearMonth(_, display, y, mo):
                ["Arctic Vault", display, String(y), mo]
        }
    }
}

struct ArcticVaultBreadcrumbBar: View {
    let phase: ArcticVaultLibraryPhase
    var onTapSegment: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(phase.breadcrumbTitles.enumerated()), id: \.offset) { idx, title in
                    if idx > 0 {
                        Image(systemName: "chevron.compact.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        onTapSegment(idx)
                    } label: {
                        Text(title)
                            .font(.caption.weight(idx == phase.breadcrumbTitles.count - 1 ? .semibold : .regular))
                            .foregroundStyle(idx == phase.breadcrumbTitles.count - 1 ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 8)
        }
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.65))
    }
}

struct ArcticVendorFolderTile: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                .lineLimit(2)
            Text("\(count) receipt\(count == 1 ? "" : "s")")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
        )
    }
}

struct NewArcticVaultFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var symbol: String = "folder.fill"

    private let symbolChoices = [
        "folder.fill",
        "film",
        "person.fill",
        "hammer.fill",
        "briefcase.fill",
        "building.columns.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder") {
                    TextField("Name (e.g. Productions)", text: $title)
                    Picker("Icon", selection: $symbol) {
                        ForEach(symbolChoices, id: \.self) { sym in
                            Label(sym, systemImage: sym).tag(sym)
                        }
                    }
                }
                Section {
                    Text(
                        "Folders add a path prefix for receipts (e.g. `Productions/Bell Media`). Use **Scan into folder** in Receipts to route new captures here."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New folder")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { create() }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }

    private func create() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            _ = try FilingCoordinator.insertRootFolder(title: t, sfSymbolName: symbol, context: modelContext)
            dismiss()
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn’t create folder",
                message: error.ratioVitaUserDescription
            )
        }
    }
}

enum ArcticVaultExplorerModel {
    struct VendorBucket: Identifiable, Hashable {
        var id: String { merchantKey }
        let merchantKey: String
        let displayTitle: String
        let receipts: [Receipt]
    }

    static func vendorBuckets(from receipts: [Receipt]) -> [VendorBucket] {
        let dict = Dictionary(grouping: receipts) { r -> String in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            return m.isEmpty ? "unknown" : m.lowercased()
        }
        return dict.keys.sorted().compactMap { key in
            guard let group = dict[key], let first = group.first else { return nil }
            let title = first.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Unknown merchant"
                : first.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            return VendorBucket(merchantKey: key, displayTitle: title, receipts: group)
        }
    }

    static func years(for merchantKey: String, receipts: [Receipt]) -> [Int] {
        let cal = Calendar.current
        let subset = receipts.filter { r in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = m.isEmpty ? "unknown" : m.lowercased()
            return k == merchantKey
        }
        let ys = Set(subset.map { cal.component(.year, from: ReceiptVaultPathing.anchorDate(for: $0)) })
        return ys.sorted(by: >)
    }

    static func monthSymbols(for merchantKey: String, year: Int, receipts: [Receipt]) -> [String] {
        let cal = Calendar.current
        let subset = receipts.filter { r in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = m.isEmpty ? "unknown" : m.lowercased()
            guard k == merchantKey else { return false }
            return cal.component(.year, from: ReceiptVaultPathing.anchorDate(for: r)) == year
        }
        var monthNumberToSymbol: [Int: String] = [:]
        for r in subset {
            let d = ReceiptVaultPathing.anchorDate(for: r)
            let mo = cal.component(.month, from: d)
            if monthNumberToSymbol[mo] == nil {
                monthNumberToSymbol[mo] = ReceiptVaultPathing.yearMonth(for: d).monthSymbol
            }
        }
        return monthNumberToSymbol.keys.sorted().compactMap { monthNumberToSymbol[$0] }
    }

    static func receipts(
        merchantKey: String,
        year: Int,
        monthSymbol: String,
        in receipts: [Receipt]
    ) -> [Receipt] {
        let cal = Calendar.current
        return receipts.filter { r in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = m.isEmpty ? "unknown" : m.lowercased()
            guard k == merchantKey else { return false }
            let d = ReceiptVaultPathing.anchorDate(for: r)
            guard cal.component(.year, from: d) == year else { return false }
            let sym = ReceiptVaultPathing.yearMonth(for: d).monthSymbol
            return sym.caseInsensitiveCompare(monthSymbol) == .orderedSame
        }
    }

    static func receipts(merchantKey: String, year: Int, in receipts: [Receipt]) -> [Receipt] {
        let cal = Calendar.current
        return receipts.filter { r in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = m.isEmpty ? "unknown" : m.lowercased()
            guard k == merchantKey else { return false }
            return cal.component(.year, from: ReceiptVaultPathing.anchorDate(for: r)) == year
        }
    }
}
