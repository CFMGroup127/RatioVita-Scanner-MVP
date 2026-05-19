import SwiftData
import SwiftUI

/// Rate tiers / position rotations on a show (deal memo page 1 equivalents).
struct ProductionShowPositionsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID: String = ""
    @AppStorage("laborSentinelAgreementCode") private var laborSentinelAgreementCode: String = ""

    @Bindable var project: ProductionProject
    @Query(sort: \LaborAgreement.title) private var laborAgreements: [LaborAgreement]

    @State private var editingRate: ShowLaborPositionRate?

    private var sortedRates: [ShowLaborPositionRate] {
        project.laborPositionRates.sorted { $0.effectiveFromDate < $1.effectiveFromDate }
    }

    private var agreement: LaborAgreement? {
        let trimmed = laborSentinelAgreementCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let match = laborAgreements.first(where: { $0.code == trimmed }) {
            return match
        }
        return laborAgreements.first
    }

    var body: some View {
        Group {
            #if os(macOS)
            LeftAlignedFormSection(
                "Positions & rates",
                footer: "Each tier is a deal-memo rotation (occupation, department, effective date). Labor Sentinel uses the latest tier on or before each crew day."
            ) {
                macBody
            }
            #else
            Section {
                iosBody
            } header: {
                Text("Positions & rates")
            } footer: {
                Text("Add a tier when you rotate role or rate mid-show. Open Labor Sentinel to enter daily hours.")
                    .font(.footnote)
            }
            #endif
        }
        .sheet(isPresented: isEditingRatePresented) {
            if let rate = editingRate {
                ShowLaborPositionRateEditSheet(rate: rate)
            }
        }
    }

    private var isEditingRatePresented: Binding<Bool> {
        Binding(
            get: { editingRate != nil },
            set: { if !$0 { editingRate = nil } }
        )
    }

    #if os(macOS)
    private var macBody: some View {
        iosBody
    }
    #endif

    private var iosBody: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if sortedRates.isEmpty {
                Text("No position tiers yet — add your first rate row or import a deal memo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .adaptiveDetailText()
            } else {
                ForEach(sortedRates, id: \.id) { rate in
                    Button {
                        editingRate = rate
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rate.occupationTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(
                                "\(rate.effectiveFromDate.formatted(date: .abbreviated, time: .omitted)) · \(rate.displayRateSummary)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if let dept = rate.department, !dept.isEmpty {
                                Text(dept)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    addRateTier()
                } label: {
                    Label("Add position / rate", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    openLaborSentinel()
                } label: {
                    Label("Open timecards", systemImage: "calendar.day.timeline.left")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addRateTier() {
        guard let agr = agreement else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = project.effectiveLaborBaseRate(for: today, calendar: cal) ?? agr.baseHourlyRateCAD
        let rate = ShowLaborPositionRate(
            effectiveFromDate: today,
            occupationTitle: "New position",
            baseHourlyRateCAD: base,
            department: project.payrollDepartment,
            productionProject: project
        )
        modelContext.insert(rate)
        try? modelContext.save()
        editingRate = rate
    }

    private func openLaborSentinel() {
        forensicActiveProductionID = project.id.uuidString
        libraryNavigationCoordinator.navigateFromHome(.laborSentinel)
    }
}
