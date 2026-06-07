import SwiftUI

/// Column-one gateway: Approvals inbox + Transport board (macOS split rail · iOS picker).
struct OperationsCommandCenterView: View {
    private enum CommandRail: String, CaseIterable, Identifiable, Hashable {
        case approvals
        case transport
        case shuttle
        case fleet
        case deliveries
        case comms
        case crisis
        case locations
        case executive

        var id: String { rawValue }

        var title: String {
            switch self {
                case .approvals: "Approvals inbox"
                case .transport: "Transport board"
                case .shuttle: "Shuttle tracker"
                case .fleet: "Fleet monitor"
                case .deliveries: "Door-to-chair"
                case .comms: "Comms pager"
                case .crisis: "Crisis matrix"
                case .locations: "Locations desk"
                case .executive: "Executive matrix"
            }
        }

        var systemImage: String {
            switch self {
                case .approvals: "checkmark.seal"
                case .transport: "car.2.fill"
                case .shuttle: "bus.fill"
                case .fleet: "map.fill"
                case .deliveries: "shippingbox.fill"
                case .comms: "bell.badge.waveform.fill"
                case .crisis: "flame.fill"
                case .locations: "mappin.and.ellipse"
                case .executive: "rectangle.grid.2x2.fill"
            }
        }
    }

    @State private var rail: CommandRail = .approvals

    var body: some View {
        #if os(macOS)
        macCommandLayout
        #else
        iosCommandLayout
        #endif
    }

    #if os(macOS)
    private var macCommandLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            List(selection: $rail) {
                ForEach(CommandRail.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .frame(width: SafeLayoutBounds.commandRailWidth)

            Divider()

            commandDetailPane
        }
        .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth, maxHeight: .infinity)
        .navigationTitle("Dispatch & gateway")
    }
    #endif

    private var iosCommandLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Module", selection: $rail) {
                ForEach(CommandRail.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            commandDetailPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Dispatch & gateway")
    }

    @ViewBuilder
    private var commandDetailPane: some View {
        Group {
            switch rail {
                case .approvals:
                    ApprovalsInboxView()
                case .transport:
                    NavigationStack {
                        TransportDispatchBoardView()
                    }
                case .shuttle:
                    NavigationStack {
                        LiveShuttleMapView()
                    }
                case .fleet:
                    NavigationStack {
                        TransportMasterDashboardView()
                    }
                case .deliveries:
                    NavigationStack {
                        ProducerDeliveryTrackerView()
                    }
                case .comms:
                    NavigationStack {
                        CommsPagerInboxView()
                    }
                case .crisis:
                    NavigationStack {
                        CrisisSplitScreenView()
                    }
                case .locations:
                    NavigationStack {
                        LocationsPAHubView()
                    }
                case .executive:
                    NavigationStack {
                        PMMacroMatrixView()
                    }
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 480,
            maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #endif
    }
}
