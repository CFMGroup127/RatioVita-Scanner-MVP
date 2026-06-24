import SwiftData
import SwiftUI

/// Bank ↔ receipt reconciliation: sidebar bank rows, **verification hub** (statement PDF + badges), ranked matches
/// only.
struct ReconciliationReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var sovereignContext = SovereignContextManager.shared

    @Query(sort: \BankTransaction.postedDate, order: .reverse) private var allTransactions: [BankTransaction]
    @Query private var allReceipts: [Receipt]

    @State private var selectedTransactionID: UUID?
    @State private var selectedMatchReceiptID: UUID?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showManualMatchSheet = false
    @State private var showStatementPDF = true
    @State private var pdfScrollRequestID: UUID?
    @State private var confirmClearPosting: BankTransaction?

    private var scopedOpenReceipts: [Receipt] {
        SovereignScopeFilter.filterReceipts(
            allReceipts.filter { !$0.isLedgerLinked && $0.trashedAt == nil },
            context: sovereignContext
        )
    }

    private var needsAttentionTransactions: [BankTransaction] {
        allTransactions.filter { tx in
            tx.matchedReceipt == nil
                && !tx.manuallyClearedForReconciliation
                && SovereignScopeFilter.bankTransactionIsVisible(
                    tx,
                    context: sovereignContext,
                    openReceipts: scopedOpenReceipts
                )
        }
    }

    private var reconciledTransactions: [BankTransaction] {
        allTransactions.filter { tx in
            (tx.matchedReceipt != nil || tx.manuallyClearedForReconciliation)
                && (tx.matchedReceipt == nil || sovereignContext.receiptIsVisible(tx.matchedReceipt!))
        }
    }

    private var openReceipts: [Receipt] {
        scopedOpenReceipts
    }

    private var selectedTransaction: BankTransaction? {
        guard let id = selectedTransactionID else { return nil }
        return allTransactions.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            bankListSidebar
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Group { verificationHubColumn }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 560)
        } detail: {
            Group { rankedMatchesColumn }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .navigationSplitViewColumnWidth(min: 380, ideal: 480, max: 720)
        }
        .navigationTitle("Reconciliation")
        .safeAreaInset(edge: .top, spacing: 0) {
            SovereignContextSwitcherBar()
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .sheet(isPresented: $showManualMatchSheet) {
            if let tx = selectedTransaction, tx.matchedReceipt == nil, !tx.manuallyClearedForReconciliation {
                ReconciliationManualReceiptSheet(
                    transaction: tx,
                    receipts: manualMatchCandidates(for: tx),
                    onPick: { receipt in link(tx, to: receipt) }
                )
            }
        }
        .onChange(of: selectedTransactionID) { _, newValue in
            if newValue == nil { showManualMatchSheet = false }
            selectedMatchReceiptID = nil
        }
        .confirmationDialog(
            "Mark this posting as cleared without linking a receipt?",
            isPresented: Binding(
                get: { confirmClearPosting != nil },
                set: { if !$0 { confirmClearPosting = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Mark cleared") {
                if let tx = confirmClearPosting {
                    markPostingClearedWithoutReceipt(tx)
                }
                confirmClearPosting = nil
            }
            Button("Cancel", role: .cancel) {
                confirmClearPosting = nil
            }
        } message: {
            Text("It moves to Reconciled so only open items stay in Needs attention.")
        }
    }

    private var bankListSidebar: some View {
        List(selection: $selectedTransactionID) {
            Section("Needs attention") {
                if needsAttentionTransactions.isEmpty {
                    Text("No unmatched postings.")
                        .foregroundStyle(.secondary)
                }
                ForEach(needsAttentionTransactions, id: \.id) { tx in
                    bankRowLabel(tx)
                        .tag(Optional(tx.id))
                }
            }
            Section("Reconciled") {
                if reconciledTransactions.isEmpty {
                    Text("Nothing reconciled yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(reconciledTransactions, id: \.id) { tx in
                    bankRowLabel(tx)
                        .tag(Optional(tx.id))
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 380)
        .navigationTitle("Reconciliation")
    }

    @ViewBuilder
    private var verificationHubColumn: some View {
        if let tx = selectedTransaction {
            if tx.matchedReceipt != nil {
                linkedVerificationHub(tx: tx)
            } else if tx.manuallyClearedForReconciliation {
                clearedVerificationHub(tx: tx)
            } else {
                unmatchedVerificationHub(tx: tx)
            }
        } else {
            VStack(spacing: DesignSystem.Spacing.md) {
                Spacer(minLength: 0)
                ContentUnavailableView(
                    "Select a bank row",
                    systemImage: "arrow.triangle.merge",
                    description: Text(
                        "Choose a posting to verify against the statement PDF and ranked receipt matches."
                    )
                )
                .frame(minWidth: 260, maxWidth: 480)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            .padding(DesignSystem.Spacing.md)
        }
    }

    @ViewBuilder
    private var rankedMatchesColumn: some View {
        if let tx = selectedTransaction {
            if let receipt = tx.matchedReceipt {
                linkedMatchesColumn(tx: tx, receipt: receipt)
            } else if tx.manuallyClearedForReconciliation {
                clearedMatchesColumn(tx: tx)
            } else {
                unmatchedMatchesColumn(tx: tx)
            }
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ContentUnavailableView(
                    "Matches",
                    systemImage: "rectangle.stack",
                    description: Text(
                        "Ranked receipt suggestions from RatioVita's matcher appear here after you select a row."
                    )
                )
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DesignSystem.Spacing.md)
        }
    }

    @ViewBuilder
    private func bankRowLabel(_ tx: BankTransaction) -> some View {
        let linked = tx.matchedReceipt != nil
        let clearedOnly = tx.manuallyClearedForReconciliation && !linked
        VStack(alignment: .leading, spacing: 6) {
            Text(tx.postedDate.formatted(date: .abbreviated, time: .omitted))
                .font(DesignSystem.Typography.callout)
            Text(!(tx.memo ?? "").isEmpty ? (tx.memo ?? "") : "—")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(formatAmount(tx.amount, currency: tx.currencyCode))
                .font(DesignSystem.Typography.subheadline.weight(.semibold))
                .foregroundStyle(amountSignColor(tx.amount))
            if linked {
                Text("Linked")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
                    .foregroundStyle(.green)
            } else if clearedOnly {
                Text("Cleared")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 56, alignment: .topLeading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func verificationBadges(for tx: BankTransaction) -> some View {
        let hasMemo = !(tx.memo ?? "").isEmpty
        let hasStatementPDF = BankStatementImportCoordinator.resolvedStatementPDFURL(for: tx) != nil
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140, maximum: 220), alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            Label("Amount verified", systemImage: "checkmark.seal.fill")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green.opacity(0.15)))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            Label("Date parsed", systemImage: "calendar.badge.checkmark")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.blue.opacity(0.12)))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            if hasMemo {
                Label("Memo present", systemImage: "text.alignleft")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            if !hasStatementPDF {
                Label(
                    "No statement PDF on disk (CSV import, renamed file, or not in Imported).",
                    systemImage: "doc.questionmark"
                )
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func unmatchedVerificationHub(tx: BankTransaction) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            statementPDFSection(tx: tx, minHeight: 120, presentation: .previewRibbon)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .background(Color.ratioVitaAdaptiveSurface.opacity(0.25))

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(tx.postedDate.formatted(date: .complete, time: .omitted))
                            .font(DesignSystem.Typography.headline)
                        Text(formatAmount(tx.amount, currency: tx.currencyCode))
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(amountSignColor(tx.amount))
                        if let memo = tx.memo, !memo.isEmpty {
                            Text(memo)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(Color.ratioVitaAdaptiveText)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    verificationBadges(for: tx)

                    Button {
                        confirmClearPosting = tx
                    } label: {
                        Label("Mark as managed / cleared", systemImage: "checkmark.circle")
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showManualMatchSheet = true
                    } label: {
                        Label("Manual match…", systemImage: "magnifyingglass")
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(DesignSystem.Spacing.lg)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ratioVitaAdaptiveBackground)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func clearedVerificationHub(tx: BankTransaction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Cleared without receipt")
                    .font(DesignSystem.Typography.headline)
                Text(tx.postedDate.formatted(date: .complete, time: .omitted))
                    .font(DesignSystem.Typography.subheadline)
                Text(formatAmount(tx.amount, currency: tx.currencyCode))
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(amountSignColor(tx.amount))
                if let memo = tx.memo, !memo.isEmpty {
                    Text(memo)
                        .font(DesignSystem.Typography.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                verificationBadges(for: tx)
                    .frame(maxWidth: .infinity, alignment: .leading)
                statementPDFSection(tx: tx, minHeight: 240)
                Button("Put back in Needs attention") {
                    undoManualClear(tx)
                }
                .buttonStyle(.bordered)
            }
            .padding(DesignSystem.Spacing.lg)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    private enum StatementPDFPresentation {
        case full
        /// Pinned strip (~top 20% of the column) for the Command Deck middle pane.
        case previewRibbon
    }

    @ViewBuilder
    private func statementPDFSection(
        tx: BankTransaction,
        minHeight: CGFloat,
        presentation: StatementPDFPresentation = .full
    ) -> some View {
        #if canImport(PDFKit)
        if BankStatementImportCoordinator.resolvedStatementPDFURL(for: tx) != nil {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                switch presentation {
                    case .full:
                        Toggle("View statement source (PDF)", isOn: $showStatementPDF)
                            .font(DesignSystem.Typography.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .previewRibbon:
                        Text("Source statement")
                            .font(DesignSystem.Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                }
                let showPDF: Bool = switch presentation {
                    case .full: showStatementPDF
                    case .previewRibbon: true
                }
                if showPDF, let url = BankStatementImportCoordinator.resolvedStatementPDFURL(for: tx) {
                    HStack(alignment: .top, spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                            StatementPDFKitView(
                                url: url,
                                approximateVerticalFraction: pdfApproximateVerticalFraction(for: tx),
                                scrollRequestToken: pdfScrollRequestID
                            )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(8.5 / 11.0, contentMode: .fit)
                            .frame(
                                maxHeight: {
                                    switch presentation {
                                        case .full: min(minHeight + 120, 640)
                                        case .previewRibbon: 200
                                    }
                                }()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
                            )
                            if presentation == .full {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Button {
                                        pdfScrollRequestID = UUID()
                                    } label: {
                                        Label(
                                            "Zoom to row (approx.)",
                                            systemImage: "arrow.up.left.and.arrow.down.right"
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    Text("Scroll uses your position among rows from the same imported PDF.")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(.tertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Button {
                                    pdfScrollRequestID = UUID()
                                } label: {
                                    Label("Scroll to this row", systemImage: "arrow.up.left.and.arrow.down.right")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: presentation == .previewRibbon ? .infinity : 560)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private func linkedVerificationHub(tx: BankTransaction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(tx.postedDate.formatted(date: .complete, time: .omitted))
                        .font(DesignSystem.Typography.headline)
                    Text(formatAmount(tx.amount, currency: tx.currencyCode))
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(amountSignColor(tx.amount))
                    if let memo = tx.memo, !memo.isEmpty {
                        Text(memo)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(Color.ratioVitaAdaptiveText)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                verificationBadges(for: tx)

                statementPDFSection(tx: tx, minHeight: 260)

                Divider()

                Button(role: .destructive) {
                    unlink(tx)
                } label: {
                    Label("Unlink receipt", systemImage: "link.slash")
                        .frame(maxWidth: 260, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .padding(DesignSystem.Spacing.lg)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func unmatchedMatchesColumn(tx: BankTransaction) -> some View {
        let matches = BankReconciliationMatcher.rankedMatches(for: tx, openReceipts: openReceipts)
        Group {
            if matches.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        Text("Ranked matches")
                            .font(DesignSystem.Typography.headline)
                            .frame(maxWidth: .infinity)
                        Text("Only receipts with the same amount and currency, scored by dates and memo overlap.")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 420)
                        ContentUnavailableView(
                            "No ranked matches",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(
                                "Use Manual match in the middle column, or import a receipt in the same currency and amount."
                            )
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignSystem.Spacing.lg)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    matchIconRail(matches: matches)
                    Divider()
                    selectedMatchCommandDeck(tx: tx, matches: matches)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .id(tx.id)
                .background(Color.ratioVitaAdaptiveBackground)
                .onAppear {
                    if selectedMatchReceiptID == nil {
                        selectedMatchReceiptID = matches.first?.receiptID
                    }
                }
            }
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func matchIconRail(matches: [BankReconciliationMatcher.Match]) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                ForEach(matches) { m in
                    if let receipt = openReceipts.first(where: { $0.id == m.receiptID }) {
                        let selected = selectedMatchReceiptID == m.receiptID
                        Button {
                            selectedMatchReceiptID = m.receiptID
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.ratioVitaAdaptiveSurface)
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        selected ? Color.accentColor : Color.ratioVitaAdaptiveBorder.opacity(0.35),
                                        lineWidth: selected ? 2 : 1
                                    )
                                Group {
                                    if let img = receipt.firstImage {
                                        Image(rvImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .frame(width: 76, height: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Potential match: \(receipt.merchant)")
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .frame(width: 92)
        .frame(maxHeight: .infinity)
        .background(Color.ratioVitaAdaptiveSurface.opacity(0.35))
    }

    @ViewBuilder
    private func selectedMatchCommandDeck(
        tx: BankTransaction,
        matches: [BankReconciliationMatcher.Match]
    ) -> some View {
        let selectedID = selectedMatchReceiptID ?? matches.first?.receiptID
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Match detail")
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let selectedID,
                       let m = matches.first(where: { $0.receiptID == selectedID }),
                       let receipt = openReceipts.first(where: { $0.id == selectedID })
                    {
                        rankedMatchRow(tx: tx, receipt: receipt, match: m)
                        NavigationLink {
                            ReceiptDetailByIDView(receiptID: selectedID)
                        } label: {
                            Label("Open in receipt workspace", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ContentUnavailableView(
                            "Select a match",
                            systemImage: "rectangle.stack",
                            description: Text("Choose a receipt thumbnail along the rail.")
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func clearedMatchesColumn(tx _: BankTransaction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Cleared posting")
                    .font(DesignSystem.Typography.headline)
                Text(
                    "No receipt is linked. This row is out of the Needs attention queue. Use Put back in the middle column if you cleared it by mistake."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func linkedMatchesColumn(tx _: BankTransaction, receipt: Receipt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Linked receipt")
                    .font(DesignSystem.Typography.headline)
                VStack(alignment: .leading, spacing: 6) {
                    Text(receipt.merchant)
                        .font(DesignSystem.Typography.title3)
                    Text(formatAmount(receipt.total, currency: receipt.currencyCode))
                        .font(DesignSystem.Typography.subheadline.weight(.semibold))
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                )
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ratioVitaAdaptiveBackground)
    }

    @ViewBuilder
    private func rankedMatchRow(
        tx: BankTransaction,
        receipt: Receipt,
        match: BankReconciliationMatcher.Match
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                confidenceBadge(match.confidence)
                Spacer()
                Text(String(format: "Score %.0f", match.totalScore))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Text(receipt.merchant)
                .font(DesignSystem.Typography.title3)
            Text(formatAmount(receipt.total, currency: receipt.currencyCode))
                .font(DesignSystem.Typography.subheadline.weight(.semibold))
            HStack(spacing: DesignSystem.Spacing.md) {
                if let d = receipt.transactionDate {
                    Label(d.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                if let dep = receipt.depositDate {
                    Label("Deposit \(dep.formatted(date: .abbreviated, time: .omitted))", systemImage: "banknote")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.secondary)

            if let days = match.bestAnchorDayDistance {
                Text("Best date anchor: \(days) day\(days == 1 ? "" : "s") from bank posting")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text("Memo overlap \(Int(match.memoOverlap * 100))%")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.tertiary)

            Button {
                link(tx, to: receipt)
            } label: {
                Label("Link", systemImage: "link")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: BankReconciliationMatcher.Confidence) -> some View {
        let (title, color): (String, Color) = switch confidence {
            case .high: ("High confidence", .green)
            case .medium: ("Medium", .orange)
            case .low: ("Low", .secondary)
        }
        Text(title)
            .font(DesignSystem.Typography.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    private func manualMatchCandidates(for tx: BankTransaction) -> [Receipt] {
        scopedOpenReceipts.filter { receipt in
            receipt.currencyCode.caseInsensitiveCompare(tx.currencyCode) == .orderedSame
        }
    }

    private func markPostingClearedWithoutReceipt(_ tx: BankTransaction) {
        tx.manuallyClearedForReconciliation = true
        let peers = BankTransactionClearHeuristics.peersToAutoClear(matching: tx, in: allTransactions)
        for p in peers {
            p.manuallyClearedForReconciliation = true
        }
        do {
            try modelContext.save()
            DesignSystem.TouchFeedback.impactMedium()
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn't save",
                message: error.ratioVitaUserDescription
            )
        }
        if !peers.isEmpty {
            UserMessageCenter.shared.present(
                title: "Similar rows cleared",
                message: "Also marked \(peers.count) similar unmatched posting(s) from the same import as cleared."
            )
        }
        selectedTransactionID = tx.id
    }

    private func undoManualClear(_ tx: BankTransaction) {
        tx.manuallyClearedForReconciliation = false
        try? modelContext.save()
        selectedTransactionID = tx.id
    }

    private func link(_ tx: BankTransaction, to receipt: Receipt) {
        if let oldTx = receipt.matchedBankTransaction, oldTx.id != tx.id {
            oldTx.matchedReceipt = nil
        }
        tx.manuallyClearedForReconciliation = false
        tx.matchedReceipt = receipt
        receipt.matchedBankTransaction = tx
        receipt.isLedgerLinked = true
        try? modelContext.save()
        selectedTransactionID = tx.id
    }

    private func unlink(_ tx: BankTransaction) {
        guard let receipt = tx.matchedReceipt else { return }
        tx.matchedReceipt = nil
        tx.manuallyClearedForReconciliation = false
        receipt.matchedBankTransaction = nil
        receipt.isLedgerLinked = false
        try? modelContext.save()
        selectedTransactionID = tx.id
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let n = NSDecimalNumber(decimal: amount)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.string(from: n) ?? "\(n) \(currency)"
    }

    private func amountSignColor(_ amount: Decimal) -> Color {
        Color.ratioVitaSignedCurrencyAmount(amount)
    }

    private func sameStatementFilenamePeers(for tx: BankTransaction) -> [BankTransaction] {
        guard let name = BankStatementImportCoordinator
            .sourceStatementPDFFilename(fromExternalReference: tx.externalReference) else { return [] }
        return allTransactions.filter {
            BankStatementImportCoordinator
                .sourceStatementPDFFilename(fromExternalReference: $0.externalReference) == name
        }.sorted { $0.postedDate < $1.postedDate }
    }

    private func pdfApproximateVerticalFraction(for tx: BankTransaction) -> CGFloat {
        let peers = sameStatementFilenamePeers(for: tx)
        guard !peers.isEmpty, let idx = peers.firstIndex(where: { $0.id == tx.id }) else { return 0.5 }
        return CGFloat(idx + 1) / CGFloat(max(peers.count, 1))
    }
}
