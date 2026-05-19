import SwiftData
import SwiftUI

/// Dedicated full-screen hub for crew timecards across active productions.
struct TimeSheetsHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent

    @Query(sort: \ProductionProject.title) private var allProjects: [ProductionProject]

    private var activeProjects: [ProductionProject] {
        allProjects.filter { $0.registryStatus != .retired }
    }

    @Query(sort: \CrewTimecardDay.workDate, order: .reverse) private var allCrewDays: [CrewTimecardDay]

    @State private var selectedProjectID: UUID?
    @State private var selectedDayID: UUID?
    @AppStorage("timeSheetsLastProjectID") private var timeSheetsLastProjectID: String = ""
    #if os(macOS)
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    #endif

    private var selectedProject: ProductionProject? {
        guard let id = selectedProjectID else { return nil }
        return activeProjects.first { $0.id == id }
    }

    private var daysForProject: [CrewTimecardDay] {
        guard let p = selectedProject else { return [] }
        return allCrewDays.filter { $0.productionProject?.id == p.id }
    }

    /// Resolve from full crew-day query so detail opens even if project filter lags SwiftData refresh.
    private var selectedDay: CrewTimecardDay? {
        guard let id = selectedDayID else { return nil }
        if let match = allCrewDays.first(where: { $0.id == id }) {
            return match
        }
        return daysForProject.first { $0.id == id }
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            timeSheetsListColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            timeSheetsDetailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationSplitViewColumnWidth(min: 450, ideal: 650, max: 900)
        }
        .resetsNavigationSplitColumnsOnLaunch()
        .navigationTitle("Time Sheets")
        .onAppear(perform: restoreLastProjectSelection)
        #else
        NavigationStack {
            timeSheetsListColumn
                .navigationDestination(isPresented: Binding(
                    get: { selectedDay != nil },
                    set: { if !$0 { selectedDayID = nil } }
                )) {
                    if let day = selectedDay {
                        TimecardWorkspaceView(
                            day: day,
                            siblingProjectDays: daysForProject,
                            showsProductionSwitcher: true,
                            productionOptions: activeProjects,
                            showsToolbarDone: true,
                            onToolbarDone: { selectedDayID = nil }
                        )
                        .navigationTitle(day.workDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
        }
        .onAppear(perform: restoreLastProjectSelection)
        #endif
    }

    private var timeSheetsListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            productionPickerPanel
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
            Divider()
            List {
                crewDaysListContent
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
        }
        #if os(macOS)
        .navigationTitle("Time Sheets")
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addCrewDay()
                } label: {
                    Label("Add day", systemImage: "plus")
                }
                .disabled(selectedProject == nil)
            }
        }
    }

    private var productionPickerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active productions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Production", selection: $selectedProjectID) {
                Text("Choose a show…").tag(UUID?.none)
                ForEach(activeProjects) { p in
                    Text(p.title)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .tag(Optional(p.id))
                }
            }
            .onChange(of: selectedProjectID) { _, _ in
                if let id = selectedProjectID {
                    timeSheetsLastProjectID = id.uuidString
                }
                selectedDayID = nil
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var crewDaysListContent: some View {
        Section("Crew days") {
            if selectedProject == nil {
                Text("Select a production above.")
                    .foregroundStyle(.secondary)
            } else if daysForProject.isEmpty {
                Text("No timecard days yet — tap **Add day**.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(daysForProject, id: \.id) { day in
                    Button {
                        selectedDayID = day.id
                    } label: {
                        timecardDayRow(day, isSelected: selectedDayID == day.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timecardDayRow(_ day: CrewTimecardDay, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.workDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                HStack(spacing: 6) {
                    if let unit = day.unitType, !unit.isEmpty {
                        Text(unit).font(.caption2)
                    }
                    if let dept = day.department, !dept.isEmpty {
                        Text(dept).font(.caption2)
                    }
                    if day.kitRentalFullTimeMode {
                        Text("Full-time kit")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(brandAccent)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var timeSheetsDetailColumn: some View {
        Group {
            if let day = selectedDay {
                NavigationStack {
                    TimecardWorkspaceView(
                        day: day,
                        siblingProjectDays: daysForProject,
                        showsProductionSwitcher: true,
                        productionOptions: activeProjects,
                        showsToolbarDone: true,
                        onToolbarDone: { selectedDayID = nil }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationTitle(day.workDate.formatted(date: .abbreviated, time: .omitted))
                }
            } else {
                ContentUnavailableView(
                    "Timecard workspace",
                    systemImage: "calendar.day.timeline.left",
                    description: Text(
                        "Choose a production, then select or add a crew day. Swap shows and units (Main, 2nd, Splinter) per row."
                    )
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(selectedDayID)
    }

    private func restoreLastProjectSelection() {
        guard selectedProjectID == nil,
              !timeSheetsLastProjectID.isEmpty,
              let uuid = UUID(uuidString: timeSheetsLastProjectID),
              activeProjects.contains(where: { $0.id == uuid }) else { return }
        selectedProjectID = uuid
    }

    private func addCrewDay() {
        guard let project = selectedProject else { return }
        let cal = Calendar.current
        let day = CrewTimecardDay(
            workDate: cal.startOfDay(for: Date()),
            productionProject: project,
            occupationTitle: project.crewOccupationTitle
        )
        KitRentalContractHelper.applyCasualKitDefaults(to: day, project: project)
        modelContext.insert(day)
        try? modelContext.save()
        selectedDayID = day.id
    }
}
