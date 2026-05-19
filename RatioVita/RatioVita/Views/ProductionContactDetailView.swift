import SwiftData
import SwiftUI

/// CRM profile: roles, shared shows (with per-show cash summary), billed vs earned ledgers, gear.
struct ProductionContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Environment(\.openURL) private var openURL
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @Bindable var contact: ProductionContact

    private var activeReceipts: [Receipt] {
        contact.linkedReceipts
            .filter { $0.trashedAt == nil }
            .sorted { ($0.transactionDate ?? $0.createdAt) > ($1.transactionDate ?? $1.createdAt) }
    }

    private var linkedProjects: [ProductionProject] {
        let projects = activeReceipts.compactMap(\.productionProject)
        var seen = Set<UUID>()
        return projects.filter { seen.insert($0.id).inserted }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var outgoingInvoices: [Receipt] {
        activeReceipts.filter { DocumentTypeOption.fromStored($0.documentType) == .outgoingInvoice }
    }

    private var cashIncomeReceipts: [Receipt] {
        activeReceipts.filter {
            switch DocumentTypeOption.fromStored($0.documentType) {
                case .incomeOrCheck, .paycheck: true
                default: false
            }
        }
    }

    private var totalBilled: Decimal {
        outgoingInvoices.reduce(0) { $0 + abs($1.total) }
    }

    private var totalEarnings: Decimal {
        cashIncomeReceipts.reduce(0) { $0 + abs($1.total) }
    }

    private func earningsOnProject(_ project: ProductionProject) -> Decimal {
        activeReceipts
            .filter { $0.productionProject?.id == project.id }
            .filter {
                switch DocumentTypeOption.fromStored($0.documentType) {
                    case .incomeOrCheck, .paycheck: true
                    default: false
                }
            }
            .reduce(0) { $0 + abs($1.total) }
    }

    private func billedOnProject(_ project: ProductionProject) -> Decimal {
        activeReceipts
            .filter { $0.productionProject?.id == project.id }
            .filter { DocumentTypeOption.fromStored($0.documentType) == .outgoingInvoice }
            .reduce(0) { $0 + abs($1.total) }
    }

    private var gearReceipts: [Receipt] {
        activeReceipts.filter { receipt in
            if let raw = receipt.filingCabinetKindRaw?.lowercased(),
               raw == DocumentCabinet.equipment.rawValue || raw == DocumentCabinet.tools.rawValue
            {
                return true
            }
            let corpus = [
                receipt.taxCategory,
                receipt.merchant,
                receipt.department,
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
            let hints = ["equipment", "rental", "camera", "grip", "generator", "catering", "kit"]
            return hints.contains { corpus.contains($0) }
        }
    }

    private var ledgerRowsSorted: [Receipt] {
        (outgoingInvoices + cashIncomeReceipts).sorted {
            ($0.transactionDate ?? $0.createdAt) > ($1.transactionDate ?? $1.createdAt)
        }
    }

    private let currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    private var mailtoURL: URL? {
        guard let raw = contact.email?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let u = URL(string: "mailto:\(raw)") { return u }
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        return URL(string: "mailto:\(encoded)")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(contact.name)
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(Color.ratioVitaAdaptiveText)
                    if let company = contact.companyName, !company.isEmpty {
                        Text(company)
                            .font(DesignSystem.Typography.bodyEmphasized)
                            .foregroundStyle(Color.ratioVitaTextSecondary)
                    }
                    if let email = contact.email, !email.isEmpty {
                        LabeledContent("Email") {
                            Text(email)
                                .textSelection(.enabled)
                        }
                    }
                    if !contact.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Roles")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            FlowTagRow(tags: contact.tags)
                        }
                    }
                    Picker("Identity", selection: $contact.entityClassification) {
                        ForEach(ContactEntityClassification.allCases, id: \.self) { kind in
                            Text(kind.displayTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: contact.entityClassification) { _, _ in
                        contact.updatedAt = .now
                        try? modelContext.save()
                    }
                    if contact.entityClassification.isInternalIdentity {
                        Text("Hidden from the external Contacts list — used as payee/recipient on stubs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        if let url = mailtoURL {
                            Button {
                                openURL(url)
                            } label: {
                                Label("Send Email", systemImage: "envelope")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            libraryNavigationCoordinator.openReceiptsFilteredToContact(contact)
                        } label: {
                            Label("View All Receipts", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("Profile")
            }

            Section {
                LabeledContent("Shows linked") {
                    Text("\(linkedProjects.count)")
                }
                LabeledContent("Total billed (outgoing invoices)") {
                    Text(totalBilled, format: .currency(code: currencyCode))
                        .foregroundStyle(brandAccent)
                        .fontWeight(.semibold)
                }
                LabeledContent("Total earnings (income & payroll)") {
                    Text(totalEarnings, format: .currency(code: currencyCode))
                        .foregroundStyle(brandAccent)
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Summary")
            } footer: {
                Text(
                    "Billed sums Outgoing Invoice documents; earnings sum Income / Check and Paycheck linked to this contact."
                )
            }

            Section {
                if linkedProjects.isEmpty {
                    Text(
                        "No production project on linked receipts yet. Assign a show when you review or file Zoho invoices."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                } else {
                    ForEach(linkedProjects, id: \.id) { project in
                        NavigationLink {
                            ProductionProjectRenameView(project: project)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(project.title)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                HStack(spacing: 12) {
                                    Text("Earned this show")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(Color.ratioVitaTextSecondary)
                                    Text(earningsOnProject(project), format: .currency(code: currencyCode))
                                        .font(DesignSystem.Typography.caption.monospacedDigit())
                                }
                                HStack(spacing: 12) {
                                    Text("Billed this show")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(Color.ratioVitaTextSecondary)
                                    Text(billedOnProject(project), format: .currency(code: currencyCode))
                                        .font(DesignSystem.Typography.caption.monospacedDigit())
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("History (shows)")
            }

            Section {
                if ledgerRowsSorted.isEmpty {
                    Text("No income or outgoing invoice receipts linked yet.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary)
                } else {
                    ForEach(ledgerRowsSorted, id: \.id) { r in
                        NavigationLink {
                            ReceiptDetailPlatformView(receipt: r)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.merchant)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(
                                    "\(r.total.formatted(.currency(code: r.currencyCode))) · \(DocumentTypeOption.fromStored(r.documentType).rawValue)"
                                )
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Ledger")
            }

            Section {
                if gearReceipts.isEmpty {
                    Text(
                        "No equipment / kit / specialized catering signals on linked receipts yet (cabinet, tax category, or merchant text)."
                    )
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                } else {
                    ForEach(gearReceipts, id: \.id) { r in
                        NavigationLink {
                            ReceiptDetailPlatformView(receipt: r)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.merchant)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text(r.total.formatted(.currency(code: r.currencyCode)))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(Color.ratioVitaTextSecondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Gear & rentals")
            }
        }
        .navigationTitle("Contact")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
    }
}

private struct FlowTagRow: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.ratioVitaAdaptiveSurface)
                    )
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pt) in result.origins.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + pt.x, y: bounds.minY + pt.y),
                proposal: ProposedViewSize(result.sizes[i])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (
        size: CGSize,
        origins: [CGPoint],
        sizes: [CGSize]
    ) {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []

        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(s)
            rowH = max(rowH, s.height)
            x += s.width + spacing
        }
        return (CGSize(width: maxW, height: y + rowH), origins, sizes)
    }
}
