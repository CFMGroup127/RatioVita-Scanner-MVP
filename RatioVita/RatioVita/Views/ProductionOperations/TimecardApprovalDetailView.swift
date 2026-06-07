import SwiftData
import SwiftUI

/// Split-screen timecard approval: digital sheet (left) + signature boxes (right).
struct TimecardApprovalDetailView: View {
    @Query(sort: \LaborAgreement.title) private var laborAgreements: [LaborAgreement]
    @Query(sort: \WorkRecord.workDate, order: .reverse) private var workRecordsLibrary: [WorkRecord]
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode = ""

    let day: CrewTimecardDay
    let siblingDays: [CrewTimecardDay]
    let rules: ProductionApprovalRule

    private var workRecordsForProject: [WorkRecord] {
        guard let pid = day.productionProject?.id else { return [] }
        return workRecordsLibrary.filter { $0.productionProject?.id == pid }
    }

    private var exportFormat: TimecardPDFFormatKind {
        if let kind = day.productionProject?.payrollDefaultDocumentKind.timecardFormat {
            return kind
        }
        return .epCanadaCrewWeekly
    }

    private var agreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        let def = LaborSentinelBootstrap.defaultAgreementCode
        return laborAgreements.first { $0.code == def } ?? laborAgreements.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            previewPane
            Divider()
            TimecardSignaturePanelView(day: day, rules: rules)
                .frame(width: SafeLayoutBounds.signaturePanelWidth)
        }
        .frame(
            maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var previewPane: some View {
        Group {
            if let agreement, let production = day.productionProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        TimecardDigitalApprovalPreview(
                            day: day,
                            siblingDays: siblingDays
                        )
                        TimecardOfficialTemplatePreviewView(
                            format: exportFormat,
                            productionTitle: production.title,
                            occupation: day.occupationTitle ?? "",
                            weekEnding: weekEndingLabel,
                            days: weekDays,
                            workRecords: workRecordsForProject,
                            agreement: agreement,
                            estimateByDayID: [:],
                            production: production
                        )
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth, alignment: .leading)
                }
            } else {
                ScrollView {
                    TimecardDigitalApprovalPreview(day: day, siblingDays: siblingDays)
                        .frame(maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth, alignment: .leading)
                }
            }
        }
        .frame(
            minWidth: 320,
            maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var weekDays: [CrewTimecardDay] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: day.workDate) else {
            return [day]
        }
        return siblingDays
            .filter { interval.contains($0.workDate) }
            .sorted { $0.workDate < $1.workDate }
    }

    private var weekEndingLabel: String {
        guard let last = weekDays.last else { return "" }
        let cal = Calendar.current
        let anchor = FraturdayCalendar.payrollAnchorStartOfDay(for: last, calendar: cal)
        let weekday = cal.component(.weekday, from: anchor)
        let daysToSaturday = (7 - weekday) % 7
        let end = cal.date(byAdding: .day, value: daysToSaturday, to: anchor) ?? anchor
        return end.formatted(date: .abbreviated, time: .omitted)
    }
}
