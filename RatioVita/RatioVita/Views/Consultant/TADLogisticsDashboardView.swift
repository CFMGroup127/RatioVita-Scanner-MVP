import SwiftData
import SwiftUI

struct TADLogisticsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrailerOperationalUnit.trailerNumber) private var trailers: [TrailerOperationalUnit]

    var body: some View {
        List {
            Section("TAD master grid") {
                if trailers.isEmpty {
                    Text("No trailers — seed from Costume console or below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(trailers) { unit in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Trailer \(unit.trailerNumber)")
                                .font(.headline)
                            Text(unit.assignedCastID)
                                .font(.caption)
                        }
                        Spacer()
                        statusIcon(unit.status)
                    }
                    .padding(.vertical, 4)
                    if unit.status == .wardrobeSecuredPendingClearance {
                        Button("Mark cast clear → release swamper") {
                            TADLogisticsController.markCastClear(unit: unit)
                            try? modelContext.save()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            Section {
                Button("Simulate AD wrap → cast en route") {
                    let unit = TrailerOperationalUnit(trailerNumber: "4", castID: "WILL")
                    modelContext.insert(unit)
                    try? TrailerWrapSequenceController.markCastWrapped(context: modelContext, unit: unit)
                }
            }
        }
        .navigationTitle("TAD console")
        .onAppear { UserFrictionAnalytics.trackViewOpened("TADLogisticsDashboard") }
    }

    @ViewBuilder
    private func statusIcon(_ state: TrailerLogisticsState) -> some View {
        switch state {
            case .roomDressedAndVerified, .wardrobeSecuredPendingClearance:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .castEnRouteToBase:
                Image(systemName: "arrow.right.circle").foregroundStyle(.orange)
            case .cleanAndLockActive:
                Image(systemName: "sparkles").foregroundStyle(.blue)
            default:
                Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }
}

struct SwamperTerminalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrailerOperationalUnit.updatedAt, order: .reverse) private var trailers: [TrailerOperationalUnit]

    var body: some View {
        List {
            ForEach(trailers.filter { $0.status == .cleanAndLockActive }) { unit in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sanitize trailer \(unit.trailerNumber)")
                        .font(.headline)
                    Button("Trailer locked — log timecard") {
                        SwamperReleaseEngine.markTrailerLocked(unit: unit)
                        try? modelContext.save()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if trailers.filter({ $0.status == .cleanAndLockActive }).isEmpty {
                Text("Awaiting TAD cast-clear releases.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Swamper mode")
    }
}
