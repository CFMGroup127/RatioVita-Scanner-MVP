import SwiftData
import SwiftUI

/// Deal-memo Review panel: contract rates and kit defaults (no retail financials).
struct DealMemoContractBlueprintView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Bindable var receipt: Receipt
    var isLocked: Bool
    var onOpenTimecard: () -> Void

    private var project: ProductionProject? { receipt.productionProject }

    private var sortedTiers: [ShowLaborPositionRate] {
        (project?.laborPositionRates ?? []).sorted { $0.effectiveFromDate > $1.effectiveFromDate }
    }

    var body: some View {
        Section {
            TextField("Show / project title", text: bindingOptional(\.invoiceClientProjectTitle))
                .disabled(isLocked)
            TextField("Production company / network", text: bindingOptional(\.invoiceClientCompany))
                .disabled(isLocked)
            TextField("Production manager", text: bindingOptional(\.invoiceProductionManagerName))
                .disabled(isLocked)
            TextField("Position (page 1)", text: bindingOptional(\.department))
                .disabled(isLocked)
        } header: {
            Label("Contract & Asset Blueprint", systemImage: "doc.text.fill")
        } footer: {
            Text(
                "Deal memos archive contract rates — not purchase totals. Financial AP/AR fields are hidden for this document type."
            )
            .font(.caption)
        }

        if let project {
            contractDailyFloorSection(project: project)
        }

        if !sortedTiers.isEmpty {
            Section("Rate tiers (stacked)") {
                ForEach(sortedTiers, id: \.id) { tier in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.occupationTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(tier.displayRateSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            "Effective \(tier.effectiveFromDate.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }

        if let project {
            Section {
                DecimalOptionalField(
                    title: "Phone — casual daily (CAD)",
                    value: kitBinding(\.defaultKitPhoneRateCAD, project: project)
                )
                .disabled(isLocked)
                DecimalOptionalField(
                    title: "Phone — full-time weekly (CAD)",
                    value: kitBinding(\.defaultKitPhoneWeeklyRateCAD, project: project)
                )
                .disabled(isLocked)
                DecimalOptionalField(
                    title: "Laptop — casual daily (CAD)",
                    value: kitBinding(\.defaultKitLaptopRateCAD, project: project)
                )
                .disabled(isLocked)
                DecimalOptionalField(
                    title: "Laptop — full-time weekly (CAD)",
                    value: kitBinding(\.defaultKitLaptopWeeklyRateCAD, project: project)
                )
                .disabled(isLocked)
                DecimalOptionalField(
                    title: "Tablet — casual daily (CAD)",
                    value: kitBinding(\.defaultKitTabletRateCAD, project: project)
                )
                .disabled(isLocked)
                DecimalOptionalField(
                    title: "Tablet — full-time weekly (CAD)",
                    value: kitBinding(\.defaultKitTabletWeeklyRateCAD, project: project)
                )
                .disabled(isLocked)
            } header: {
                Text("Kit rental defaults (show)")
            } footer: {
                Text(
                    "Casual dailies use per-day rates; full-time positions use weekly allowances on each timecard row."
                )
                .font(.caption)
            }

            Section {
                Button(action: onOpenTimecard) {
                    Label("Open timecard workspace", systemImage: "calendar.day.timeline.left")
                }
                .disabled(isLocked)
            } footer: {
                Text("Use **Time Sheets** in the sidebar to jump between productions during the same pay week.")
                    .font(.caption)
            }
        }

        Section("Filing notes") {
            TextField("Notes", text: bindingOptional(\.notes), axis: .vertical)
                .lineLimit(2...6)
                .disabled(isLocked)
            TextField("Handwritten annotations", text: bindingOptional(\.annotations), axis: .vertical)
                .lineLimit(2...8)
                .disabled(isLocked)
        }
    }

    @ViewBuilder
    private func contractDailyFloorSection(project: ProductionProject) -> some View {
        if let tier = sortedTiers.first {
            ContractDailyFloorEditors(tier: tier, isLocked: isLocked)
        } else {
            Section {
                Button {
                    createDefaultFlatTier(project: project)
                } label: {
                    Label("Add flat daily tier (e.g. $300 / 14h)", systemImage: "plus.circle")
                }
                .disabled(isLocked)
            } header: {
                Text("Contract daily floor (editable)")
            } footer: {
                Text("Creates a show rate tier linked to this deal memo — no Labor Sentinel required.")
                    .font(.caption)
            }
        }
    }

    private func createDefaultFlatTier(project: ProductionProject) {
        let occupation =
            receipt.department?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? project.crewOccupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? "Deal memo position"
        let tier = ShowLaborPositionRate(
            effectiveFromDate: Calendar.current.startOfDay(for: Date()),
            occupationTitle: occupation,
            baseHourlyRateCAD: 0,
            rateKindRaw: DealMemoRateKind.flatDaily.rawValue,
            flatDailyRateCAD: 300,
            flatGuaranteeHours: 14,
            productionProject: project
        )
        modelContext.insert(tier)
        project.updatedAt = .now
        try? modelContext.save()
    }

    private func bindingOptional(_ keyPath: ReferenceWritableKeyPath<Receipt, String?>) -> Binding<String> {
        Binding(
            get: { receipt[keyPath: keyPath] ?? "" },
            set: {
                let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                receipt[keyPath: keyPath] = t.isEmpty ? nil : t
            }
        )
    }
}

private struct ContractDailyFloorEditors: View {
    @Bindable var tier: ShowLaborPositionRate
    var isLocked: Bool

    var body: some View {
        Section {
            Picker("Rate kind", selection: $tier.rateKind) {
                Text("Flat daily guarantee").tag(DealMemoRateKind.flatDaily)
                Text("Hourly").tag(DealMemoRateKind.hourly)
            }
            .disabled(isLocked)

            if tier.rateKind == .flatDaily {
                DecimalOptionalField(title: "Flat daily rate (CAD)", value: $tier.flatDailyRateCAD)
                    .disabled(isLocked)
                Stepper(
                    "Guaranteed hours: \(tier.flatGuaranteeHours ?? 14)h",
                    value: Binding(
                        get: { tier.flatGuaranteeHours ?? 14 },
                        set: {
                            tier.flatGuaranteeHours = $0
                            tier.updatedAt = .now
                        }
                    ),
                    in: 8...16
                )
                .disabled(isLocked)
            } else {
                DecimalOptionalField(
                    title: "Base hourly (CAD)",
                    value: Binding(
                        get: { tier.baseHourlyRateCAD },
                        set: {
                            tier.baseHourlyRateCAD = $0 ?? 0
                            tier.updatedAt = .now
                        }
                    )
                )
                .disabled(isLocked)
            }
        } header: {
            Text("Contract daily floor (editable)")
        } footer: {
            Text("Primary rate tier for this show — updates timecard Sentinel math.")
                .font(.caption)
        }
        .onChange(of: tier.rateKind) { _, _ in tier.updatedAt = .now }
        .onChange(of: tier.flatDailyRateCAD) { _, _ in tier.updatedAt = .now }
        .onChange(of: tier.flatGuaranteeHours) { _, _ in tier.updatedAt = .now }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

extension DealMemoContractBlueprintView {
    private func kitBinding(
        _ keyPath: ReferenceWritableKeyPath<ProductionProject, Decimal?>,
        project: ProductionProject
    ) -> Binding<Decimal?> {
        Binding(
            get: { project[keyPath: keyPath] },
            set: {
                project[keyPath: keyPath] = $0
                project.updatedAt = .now
            }
        )
    }
}
