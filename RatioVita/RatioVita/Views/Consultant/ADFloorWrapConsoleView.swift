import SwiftData
import SwiftUI

/// 2nd / Floor AD — tap wrap → DTR + TAD cast en route (Sprint RRR).
struct ADFloorWrapConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""

    @Query(sort: \TrailerOperationalUnit.trailerNumber) private var trailers: [TrailerOperationalUnit]
    @Query(sort: \DailyTimeReportEntry.wrapTimestamp, order: .reverse) private var recentDTR: [DailyTimeReportEntry]

    @State private var productionTitle = "Sanctuary"
    @State private var castID = "WILL"
    @State private var workerToken = "CAST-WILL"
    @State private var department = "Cast"
    @State private var trailerNumber = "4"
    @State private var wrappedByRole = "2nd AD"
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Production") {
                TextField("Show title", text: $productionTitle)
                TextField("Cast / crew ID", text: $castID)
                TextField("Worker token", text: $workerToken)
                TextField("Department", text: $department)
                TextField("Trailer #", text: $trailerNumber)
                Picker("Wrapped by", selection: $wrappedByRole) {
                    Text("2nd AD").tag("2nd AD")
                    Text("Floor AD").tag("Floor AD")
                }
            }
            Section {
                Button("Wrap — push DTR + notify TAD") {
                    performWrap()
                }
                .buttonStyle(.borderedProminent)
            } footer: {
                Text(
                    "Instantly creates a Daily Time Report entry and sets trailer status to Cast En Route on the TAD console."
                )
            }
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Recent DTR wraps (\(recentDTR.prefix(8).count))") {
                if recentDTR.isEmpty {
                    Text("No wraps logged yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(recentDTR.prefix(8)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.castDisplayID) · \(entry.wrappedByRole)")
                            .font(.headline)
                        Text(entry.workDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                        if let wrap = entry.wrapTimestamp {
                            Text("Wrap \(wrap.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                        }
                    }
                }
            }
            Section("Live trailer state") {
                ForEach(trailers) { unit in
                    HStack {
                        Text("Trailer \(unit.trailerNumber)")
                        Spacer()
                        Text(trailerStatusLabel(unit.status))
                            .font(.caption)
                            .foregroundStyle(unit.status == .castEnRouteToBase ? .orange : .secondary)
                    }
                }
            }
        }
        .navigationTitle("AD floor wrap")
        .onAppear {
            UserFrictionAnalytics.trackViewOpened("ADFloorWrapConsole")
            if productionTitle == "Sanctuary", forensicActiveProductionID.isEmpty == false {
                // keep default
            }
        }
    }

    private func performWrap() {
        do {
            let result = try ADWrapTriggerService.wrapCastMember(
                context: modelContext,
                castDisplayID: castID,
                workerToken: workerToken,
                department: department,
                productionTitle: productionTitle,
                trailerNumber: trailerNumber,
                wrappedByRole: wrappedByRole
            )
            statusMessage =
                "Wrapped \(castID). DTR #\(result.dtrEntry.id.uuidString.prefix(8)) · Trailer \(result.trailerUnit.trailerNumber) → cast en route."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func trailerStatusLabel(_ state: TrailerLogisticsState) -> String {
        switch state {
            case .castEnRouteToBase: "Cast en route"
            case .roomDressedAndVerified: "Room dressed"
            case .cleanAndLockActive: "Awaiting swamper"
            default: state.label
        }
    }
}

extension TrailerLogisticsState {
    fileprivate var label: String {
        switch self {
            case .standby: "Standby"
            case .castEnRouteToBase: "En route"
            case .roomDressedAndVerified: "Dressed"
            case .castOccupied: "In room"
            case .wardrobeSecuredPendingClearance: "Wardrobe secured"
            case .cleanAndLockActive: "Swamper pending"
        }
    }
}
