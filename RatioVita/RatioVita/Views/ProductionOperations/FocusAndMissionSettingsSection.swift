import SwiftUI

/// Focus modes, executive proxy, operational role, and testing mission anchor.
struct FocusAndMissionSettingsSection: View {
    @ObservedObject private var mission = TestingMissionManager.shared
    @State private var focusMode: SovereignFocusMode = HierarchyCommsEngine.activeFocusMode
    @State private var proxyName: String = HierarchyCommsEngine.executiveProxyName
    @State private var userRole: String = HierarchyCommsEngine.userOperationalRole
    @State private var missionDraft: String = ""

    var body: some View {
        Group {
            Section("Focus & hierarchy comms") {
                Picker("Active focus", selection: $focusMode) {
                    ForEach(SovereignFocusMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                TextField("Executive proxy (PA name)", text: $proxyName)
                TextField("Your on-set role", text: $userRole)
                Button("Save focus settings") { saveFocus() }
                    .buttonStyle(.bordered)
            }
            Section {
                Toggle("Show mission HUD banner", isOn: Binding(
                    get: { mission.isHUDVisible },
                    set: { mission.setHUDVisible($0) }
                ))
                TextField("Active test mission", text: $missionDraft, axis: .vertical)
                    .lineLimit(2...4)
                Button("Pin mission") {
                    mission.setMission(missionDraft)
                }
                .buttonStyle(.borderedProminent)
            } header: {
                Text("Testing mission anchor")
            } footer: {
                Text("Mission text attaches to shake-to-feedback tickets. HUD hides via Module control cockpit.")
            }
        }
        .onAppear {
            missionDraft = mission.activeMission
        }
    }

    private func saveFocus() {
        HierarchyCommsEngine.activeFocusMode = focusMode
        HierarchyCommsEngine.executiveProxyName = proxyName
        HierarchyCommsEngine.userOperationalRole = userRole
    }
}
