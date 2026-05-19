import SwiftData
import SwiftUI

/// Forensic stream: **work days**, **filed receipts**, **bank postings**, and **verified-deletion tombstones**.
/// **Pinned** year/month chrome + month **radar** (with dot strip); only the **activity stream** below scrolls.
/// Distinct from the Finder-style **Review** workbench (`ReceiptReviewView`).
struct ProductionTimelineView: View {
    @Environment(\.brandAccent) private var brandAccent

    @Query(
        filter: #Predicate<Receipt> { !$0.pendingHumanReview && $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var libraryReceipts: [Receipt]

    @Query(sort: \WorkRecord.workDate, order: .reverse)
    private var workRecords: [WorkRecord]

    @Query(sort: \BankTransaction.postedDate, order: .reverse)
    private var bankTransactions: [BankTransaction]

    @Query(sort: \RecordTombstone.createdAt, order: .reverse)
    private var recordTombstones: [RecordTombstone]

    @Query(sort: \ProductionProject.title)
    private var productionProjects: [ProductionProject]

    @Query(sort: \LaborAgreement.title)
    private var laborAgreements: [LaborAgreement]

    @Query(sort: \CrewTimecardDay.workDate, order: .reverse)
    private var crewTimecardDays: [CrewTimecardDay]

    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""
    @AppStorage("timelineIncludeRetiredProductions") private var timelineIncludeRetiredProductions = false
    @State private var showProductionRegistry = false

    @State private var selectedProjectFilterID: UUID?
    @State private var radarMonthAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var radarSelectedDay: Date?
    @State private var timelinePickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var timelinePickerMonth: Int = Calendar.current.component(.month, from: Date())

    private let calendar = Calendar.current

    private var productionProjectsForPicker: [ProductionProject] {
        productionProjects.filter { timelineIncludeRetiredProductions || $0.registryStatus == .active }
    }

    /// When a production filter is on and the project has a radar hex, tint **work** + **expense** dots that color.
    private var radarReceiptActivityTint: Color? {
        guard let pid = selectedProjectFilterID,
              let p = productionProjects.first(where: { $0.id == pid }) else { return nil }
        let raw = p.timelineColorHex?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return nil }
        return Color(hex: raw)
    }

    private enum Row: Identifiable {
        case work(WorkRecord)
        case receipt(Receipt)
        case bank(BankTransaction)
        case tombstone(RecordTombstone)

        var id: String {
            switch self {
                case let .work(w): "work-\(w.id.uuidString)"
                case let .receipt(r): "rcpt-\(r.id.uuidString)"
                case let .bank(b): "bank-\(b.id.uuidString)"
                case let .tombstone(t): "tomb-\(t.id.uuidString)"
            }
        }

        var sortDate: Date {
            switch self {
                case let .work(w): w.workDate
                case let .receipt(r): r.transactionDate ?? r.createdAt
                case let .bank(b): b.postedDate
                case let .tombstone(t): t.createdAt
            }
        }
    }

    private func receiptMatchesProject(_ rc: Receipt, projectID: UUID) -> Bool {
        if rc.productionProject?.id == projectID { return true }
        return rc.workSessions.contains { $0.productionProject?.id == projectID }
    }

    private func workRecordMatchesProject(_ w: WorkRecord, projectID: UUID) -> Bool {
        w.productionProject?.id == projectID
    }

    private func bankMatchesProject(_ tx: BankTransaction, projectID: UUID) -> Bool {
        guard let r = tx.matchedReceipt else { return false }
        return receiptMatchesProject(r, projectID: projectID)
    }

    private func tombstoneMatchesProject(_ t: RecordTombstone, projectID: UUID) -> Bool {
        t.productionProjectID == projectID
    }

    private var sentinelAgreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        let def = LaborSentinelBootstrap.defaultAgreementCode
        return laborAgreements.first { $0.code == def } ?? laborAgreements.first
    }

    private func paycheckSentinelVariance(_ rc: Receipt) -> Bool {
        guard let agr = sentinelAgreement else { return false }
        return SentinelPayrollEngine.paycheckShowsVariance(
            paycheck: rc,
            allDays: crewTimecardDays,
            agreement: agr
        )
    }

    private var rows: [Row] {
        let w = workRecords.map { Row.work($0) }
        let r = libraryReceipts.map { Row.receipt($0) }
        let b = bankTransactions.map { Row.bank($0) }
        let t = recordTombstones.map { Row.tombstone($0) }
        return (w + r + b + t).sorted { $0.sortDate > $1.sortDate }
    }

    private var filteredRows: [Row] {
        guard let pid = selectedProjectFilterID else { return rows }
        return rows.filter { row in
            switch row {
                case let .work(w): workRecordMatchesProject(w, projectID: pid)
                case let .receipt(rc): receiptMatchesProject(rc, projectID: pid)
                case let .bank(tx): bankMatchesProject(tx, projectID: pid)
                case let .tombstone(t): tombstoneMatchesProject(t, projectID: pid)
            }
        }
    }

    private var displayedRows: [Row] {
        guard let day = radarSelectedDay else { return filteredRows }
        return filteredRows.filter { calendar.isDate($0.sortDate, inSameDayAs: day) }
    }

    private var radarBuckets: [DayActivityBucket] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: radarMonthAnchor) else { return [] }
        let start = calendar.startOfDay(for: monthInterval.start)
        guard let dayRange = calendar.range(of: .day, in: .month, for: start) else { return [] }

        var map: [Date: DayActivityBucket] = [:]
        for d in dayRange {
            guard let day = calendar.date(byAdding: .day, value: d - 1, to: start) else { continue }
            let sod = calendar.startOfDay(for: day)
            map[sod] = DayActivityBucket(calendarDay: sod, work: 0, income: 0, expense: 0)
        }

        for row in filteredRows {
            let sod = calendar.startOfDay(for: row.sortDate)
            guard monthInterval.contains(sod) else { continue }
            var bucket = map[sod] ?? DayActivityBucket(calendarDay: sod, work: 0, income: 0, expense: 0)
            switch row {
                case .work:
                    bucket.work += 1
                case .receipt:
                    bucket.expense += 1
                case let .bank(tx):
                    if tx.amount >= 0 {
                        bucket.income += 1
                    } else {
                        bucket.expense += 1
                    }
                case .tombstone:
                    bucket.expense += 1
            }
            map[sod] = bucket
        }
        return map.values.sorted { $0.calendarDay < $1.calendarDay }
    }

    /// O(1) lookup for radar cells (only keys in the visible month are populated).
    private var radarBucketByStartOfDay: [Date: DayActivityBucket] {
        Dictionary(uniqueKeysWithValues: radarBuckets.map { (calendar.startOfDay(for: $0.calendarDay), $0) })
    }

    private var timelineYearOptions: [Int] {
        let yNow = calendar.component(.year, from: Date())
        let fromRows = rows.map { calendar.component(.year, from: $0.sortDate) }
        let lo = min(fromRows.min() ?? yNow, yNow) - 2
        let hi = max(fromRows.max() ?? yNow, yNow) + 2
        return Array(lo...hi)
    }

    private func syncPickersFromRadarAnchor() {
        timelinePickerYear = calendar.component(.year, from: radarMonthAnchor)
        timelinePickerMonth = calendar.component(.month, from: radarMonthAnchor)
    }

    private func applyRadarAnchorFromPickersIfNeeded() {
        let curY = calendar.component(.year, from: radarMonthAnchor)
        let curM = calendar.component(.month, from: radarMonthAnchor)
        guard timelinePickerYear != curY || timelinePickerMonth != curM else { return }
        var dc = DateComponents()
        dc.year = timelinePickerYear
        dc.month = timelinePickerMonth
        dc.day = 1
        if let d = calendar.date(from: dc) {
            withAnimation(.snappy(duration: 0.22)) {
                radarMonthAnchor = calendar.startOfDay(for: d)
            }
        }
    }

    private func workRecordsForCoincidence() -> [WorkRecord] {
        guard let pid = selectedProjectFilterID else { return workRecords }
        return workRecords.filter { workRecordMatchesProject($0, projectID: pid) }
    }

    private func invoicesForCoincidence() -> [Receipt] {
        libraryReceipts.filter { rc in
            let t = DocumentTypeOption.fromStored(rc.documentType)
            guard t == .outgoingInvoice || t == .invoice else { return false }
            if let pid = selectedProjectFilterID {
                return receiptMatchesProject(rc, projectID: pid)
            }
            return true
        }
    }

    private func dayDistance(_ a: Date, _ b: Date) -> Int {
        let da = calendar.startOfDay(for: a)
        let db = calendar.startOfDay(for: b)
        return abs(calendar.dateComponents([.day], from: da, to: db).day ?? 999)
    }

    /// ±2 calendar days of a **WorkRecord** or **Invoice** (Zoho-style outgoing) in the current production filter.
    private func hasForensicCoincidence(for receipt: Receipt) -> Bool {
        let rDay = receipt.transactionDate ?? receipt.createdAt
        for w in workRecordsForCoincidence() {
            if dayDistance(rDay, w.workDate) <= 2 { return true }
        }
        for inv in invoicesForCoincidence() where inv.id != receipt.id {
            let invDay = inv.transactionDate ?? inv.createdAt
            if dayDistance(rDay, invDay) <= 2 { return true }
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            timelineYearMonthPicker
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xs)

            ProductionTimelineCalendarRadarView(
                monthAnchor: $radarMonthAnchor,
                bucketByStartOfDay: radarBucketByStartOfDay,
                selectedDay: $radarSelectedDay,
                showsTopMonthNavigation: false,
                receiptActivityTint: radarReceiptActivityTint
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)
            .animation(.snappy(duration: 0.22), value: radarMonthAnchor)

            if radarSelectedDay != nil {
                HStack {
                    Text("Day filter active")
                        .font(DesignSystem.Typography.caption)
                    Spacer()
                    Button("Clear day") {
                        radarSelectedDay = nil
                    }
                    .font(DesignSystem.Typography.caption)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, 6)
                .background(Color.ratioVitaAdaptiveSurface.opacity(0.6))
            }

            ScrollView {
                if displayedRows.isEmpty {
                    ContentUnavailableView(
                        "Timeline",
                        systemImage: "calendar.day.timeline.left",
                        description: Text(emptyDescription)
                    )
                    .frame(minHeight: 280)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ForEach(displayedRows) { row in
                            timelineStreamCard(for: row)
                        }
                    }
                    .transaction { $0.disablesAnimations = true }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.ratioVitaAdaptiveBackground)
        .navigationTitle("Timeline")
        #if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
            .onAppear {
                let c = Calendar.current
                if let start = c.date(from: c.dateComponents([.year, .month], from: Date())) {
                    radarMonthAnchor = start
                }
                syncPickersFromRadarAnchor()
            }
            .onChange(of: radarMonthAnchor) { _, _ in
                syncPickersFromRadarAnchor()
            }
            .onChange(of: timelinePickerYear) { _, _ in
                applyRadarAnchorFromPickersIfNeeded()
            }
            .onChange(of: timelinePickerMonth) { _, _ in
                applyRadarAnchorFromPickersIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Production", selection: $selectedProjectFilterID) {
                        Text("All productions").tag(nil as UUID?)
                        ForEach(productionProjectsForPicker) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .automatic) {
                    Toggle("Retired", isOn: $timelineIncludeRetiredProductions)
                        .help("Show retired productions in this menu.")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProductionRegistry = true
                    } label: {
                        Label("Manage productions", systemImage: "building.columns.fill")
                    }
                }
            }
            .sheet(isPresented: $showProductionRegistry) {
                NavigationStack {
                    ProductionWorkspaceView()
                }
                #if os(iOS) || os(visionOS)
                .presentationDetents([.large])
                #endif
            }
            .onChange(of: timelineIncludeRetiredProductions) { _, _ in
                if let id = selectedProjectFilterID,
                   !productionProjectsForPicker.contains(where: { $0.id == id })
                {
                    selectedProjectFilterID = nil
                }
            }
    }

    private var timelineYearMonthPicker: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Picker("Year", selection: $timelinePickerYear) {
                ForEach(timelineYearOptions, id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 120, alignment: .leading)

            Picker("Month", selection: $timelinePickerMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthSymbol(m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                let now = Date()
                if let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
                    withAnimation(.snappy(duration: 0.22)) {
                        radarMonthAnchor = start
                        radarSelectedDay = nil
                    }
                }
            } label: {
                Text("This month")
                    .font(DesignSystem.Typography.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private func monthSymbol(_ month: Int) -> String {
        var comps = DateComponents()
        comps.month = month
        comps.day = 1
        comps.year = 2000
        guard let date = calendar.date(from: comps) else { return "\(month)" }
        return date.formatted(.dateTime.month(.wide))
    }

    private var emptyDescription: String {
        if radarSelectedDay != nil {
            return "Nothing on this calendar day for the current filters. Clear the day filter or pick another day in the radar."
        }
        if selectedProjectFilterID != nil {
            return "Nothing is linked to this production yet. Assign a show on receipts or time sheets, or match bank rows to receipts that carry the project."
        }
        return "File receipts, import time sheets, and load bank rows to see work, spend, and postings together by date."
    }

    @ViewBuilder
    private func timelineStreamCard(for row: Row) -> some View {
        switch row {
            case let .work(w):
                if let src = w.sourceReceipt {
                    NavigationLink {
                        ReceiptDetailPlatformView(receipt: src)
                    } label: {
                        streamCardChrome {
                            workRowLabel(w)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    streamCardChrome {
                        workRowLabel(w)
                    }
                }
            case let .receipt(rc):
                NavigationLink {
                    ReceiptDetailPlatformView(receipt: rc)
                } label: {
                    streamCardChrome(leftStripeTint: paycheckSentinelVariance(rc) ? Color.orange : nil) {
                        receiptRow(rc)
                    }
                }
                .buttonStyle(.plain)
            case let .bank(tx):
                streamCardChrome {
                    bankRow(tx)
                }
            case let .tombstone(t):
                streamCardChrome(leftStripeTint: Color.ratioVitaError) {
                    tombstoneRow(t)
                }
        }
    }

    private func streamCardChrome(
        leftStripeTint: Color? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let stripe = leftStripeTint ?? brandAccent
        return HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(stripe.opacity(0.85))
                .frame(width: 4)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
        )
    }

    private func mtoVerifiedCatering(for w: WorkRecord) -> Bool {
        guard let p = w.productionProject, p.laborCateringPortalMode else { return false }
        let d0 = calendar.startOfDay(for: w.workDate)
        return crewTimecardDays.contains { d in
            d.productionProject?.id == p.id
                && calendar.startOfDay(for: d.workDate) == d0
                && d.travelLogMTOVerified
        }
    }

    @ViewBuilder
    private func workRowLabel(_ w: WorkRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "clock")
                    .foregroundStyle(brandAccent)
                Text(w.workDate.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.callout.weight(.semibold))
                Spacer(minLength: 0)
                if mtoVerifiedCatering(for: w) {
                    Image(systemName: "truck.box.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brandAccent)
                        .accessibilityLabel("Travel log verified")
                }
            }
            if let t = w.showTitle, !t.isEmpty {
                Text(t)
                    .font(DesignSystem.Typography.subheadline)
            }
            if let h = w.hoursWorked {
                Text(String(format: "%.2f h", h))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            if let p = w.productionProject {
                Text(p.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func receiptRow(_ rc: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text((rc.transactionDate ?? rc.createdAt).formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.callout.weight(.semibold))
            }
            Text(rc.merchant)
                .font(DesignSystem.Typography.subheadline)
            Text(DocumentTypeOption.fromStored(rc.documentType).rawValue)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.tertiary)
            if hasForensicCoincidence(for: rc) {
                Label("Business probability (±2d)", systemImage: "chart.line.uptrend.xyaxis")
                    .font(DesignSystem.Typography.caption2.weight(.semibold))
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.22)))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.45), lineWidth: 1))
                    .accessibilityHint(
                        "Expense falls within two days of a work day or invoice on the filtered timeline."
                    )
            }
            if rc.businessUseVerifiedByTimeSheet {
                Label("Verified by time sheet", systemImage: "checkmark.seal.fill")
                    .font(DesignSystem.Typography.caption2.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(brandAccent))
                    .accessibilityHint("Business use aligned with a time sheet work day.")
            }
            if paycheckSentinelVariance(rc) {
                Label("Pay variance", systemImage: "exclamationmark.shield.fill")
                    .font(DesignSystem.Typography.caption2.weight(.semibold))
                    .foregroundStyle(Color.ratioVitaAdaptiveText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.28)))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.55), lineWidth: 1))
                    .accessibilityHint(
                        sentinelAgreement?.effectiveCalculatorKind == .iatse411Chef
                            ? "Paycheck gross is below the Labor Sentinel modeled gross for this production week "
                            + "(threshold \(SentinelPayrollEngine.defaultPaycheckVarianceToleranceCAD) CAD)."
                            : "Paycheck gross differs from the Labor Sentinel model for this production week (threshold "
                            + "\(SentinelPayrollEngine.defaultPaycheckVarianceToleranceCAD) CAD)."
                    )
            }
        }
    }

    private func bankRow(_ tx: BankTransaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: tx.amount >= 0 ? "arrow.down.circle" : "arrow.up.circle")
                    .foregroundStyle(tx.amount >= 0 ? Color.ratioVitaSuccess : Color.ratioVitaAdaptiveText)
                Text(tx.postedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(DesignSystem.Typography.callout.weight(.semibold))
            }
            if let memo = tx.memo, !memo.isEmpty {
                Text(memo)
                    .font(DesignSystem.Typography.subheadline)
                    .lineLimit(2)
            }
            Text(tx.amount.formatted(.currency(code: tx.currencyCode)))
                .font(DesignSystem.Typography.caption.monospacedDigit())
                .foregroundStyle(Color.ratioVitaSignedCurrencyAmount(tx.amount))
        }
    }

    private func tombstoneRow(_ t: RecordTombstone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(Color.secondary)
                    Rectangle()
                        .fill(Color.ratioVitaAdaptiveText.opacity(0.55))
                        .frame(height: 2.5)
                        .rotationEffect(.degrees(-18))
                        .padding(.horizontal, -2)
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(DesignSystem.Typography.callout.weight(.semibold))
                    Text(t.merchantSummary)
                        .font(DesignSystem.Typography.subheadline)
                        .strikethrough(true, color: Color.secondary)
                }
                Spacer(minLength: 0)
                Text("Deleted")
                    .font(DesignSystem.Typography.caption2.weight(.bold))
                    .foregroundStyle(Color.ratioVitaError)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.ratioVitaError.opacity(0.16))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.ratioVitaError.opacity(0.45), lineWidth: 1)
                    )
                    .accessibilityAddTraits(.isStaticText)
            }

            Text("Verified record removed from the library")
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(Color.ratioVitaError)

            Text(t.totalSummary.formatted(.currency(code: t.currencyCode)))
                .font(DesignSystem.Typography.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Reason: \(t.reason)")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.secondary)
            Text("Authorized by \(t.authorizedBy)")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted verified document tombstone: \(t.merchantSummary)")
    }
}

#Preview {
    NavigationStack {
        ProductionTimelineView()
    }
    .modelContainer(SampleData.previewContainer)
}
