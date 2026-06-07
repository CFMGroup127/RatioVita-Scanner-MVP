#if os(macOS)
import AppKit
#endif
import SwiftData
import SwiftUI

/// Central consultant program — legal gate, diagnostics, siloed modules.
struct ExpertOnboardingHubView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var session = ConsultantSessionManager.shared
    @Query(sort: \ExpertConsultantProfile.createdAt, order: .reverse) private var profiles: [ExpertConsultantProfile]

    @State private var selectedProfile: ExpertConsultantProfile?
    @State private var showLegal = false
    @State private var productionTitle = "Sanctuary — IA 873 cohort"
    @State private var dealMemoOCR = ""
    @State private var legalName = ""
    @State private var address = ""
    @State private var exportStatus: String?

    private var activeProfile: ExpertConsultantProfile? {
        if let id = session.activeProfileID {
            return profiles.first { $0.id == id }
        }
        return selectedProfile ?? profiles.first
    }

    var body: some View {
        List {
            Section("Program mode") {
                Toggle("Expert consultant program", isOn: Binding(
                    get: { session.programModeEnabled },
                    set: { session.setProgramEnabled($0) }
                ))
            }
            Section("Cohort setup (same-show isolation)") {
                TextField("Locked production title", text: $productionTitle)
                Picker("Department scope", selection: $seedDepartment) {
                    ForEach(IndustryDepartmentScope.allCases) { dept in
                        Text(dept.displayName).tag(dept)
                    }
                }
                Button("Seed department head profile") { seedHead() }
                Button("Seed accounting vault profile") { seedAccounting() }
            }
            SetOSRolePickerSection()
            if SetOSOnboardingCoordinator.shared.isComplete {
                SetOSPersonaSwitcherSection()
            }
            if let profile = activeProfile {
                profileSection(profile)
            } else {
                Section {
                    Text("Create or select a consultant profile to begin.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                let onboarding = SetOSOnboardingCoordinator.shared
                SetOSAppShellView(
                    department: onboarding.activeIndustryScope ?? activeProfile?.department,
                    tier: activeProfile?.tier
                ) { intent in
                    NativeLauncherShortcutManager.launch(intent)
                }
            } header: {
                Text("SetOS shell · dock & contextual consoles")
            } footer: {
                Text(
                    "iOS: Settings → RatioVita → Siri & Search, or Shortcuts app — add RV tiles. macOS: drag aliases using URLs from DesktopShortcutConfig.json."
                )
            }
            Section("Rollout strategy") {
                Text(
                    "Phase 1: isolated specialist sandboxes (this program). Phase 2: Costumes + Transport + TAD triad on one trusted show."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Expert program")
        .sheet(isPresented: $showLegal) {
            if let profile = activeProfile {
                NavigationStack {
                    FlashcardLegalGatekeeperView(profile: profile) {
                        showLegal = false
                    }
                }
            }
        }
        .onAppear {
            UserFrictionAnalytics.trackViewOpened("ExpertOnboardingHub")
        }
    }

    @State private var seedDepartment: IndustryDepartmentScope = .transport

    @ViewBuilder
    private func profileSection(_ profile: ExpertConsultantProfile) -> some View {
        Section("Active profile") {
            LabeledContent("Token", value: profile.anonymousToken)
            LabeledContent("Department", value: profile.department.displayName)
            LabeledContent("Show", value: profile.activeProductionTitle)
            LabeledContent("Legal", value: profile.legalTokenHash.isEmpty ? "Pending" : "Verified")
            if !LegalShieldGatekeeper.isLegalComplete(profile: profile) {
                Button("Complete NDA / NCA cards") { showLegal = true }
            }
        }
        Section("Immutable onboarding lock") {
            TextField("Legal name (vault only)", text: $legalName)
            TextField("Address (vault only)", text: $address)
            TextField("Deal memo page 1 OCR paste", text: $dealMemoOCR, axis: .vertical)
                .lineLimit(3...8)
            Button("Lock profile from page 1 harvest") { lockProfile(profile) }
        }
        if LegalShieldGatekeeper.isLegalComplete(profile: profile) {
            Section("Consultant tools") {
                Button("Export onboarding PDF package") { exportPDF(profile) }
                if let exportStatus {
                    Text(exportStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Expert diagnostic form") {
                    ExpertDiagnosticFormView(profile: profile)
                }
                NavigationLink("Submit consult timecard") {
                    ConsultantTimecardSubmitView(profile: profile)
                }
                NavigationLink("Department forum") {
                    IsolatedDepartmentForumView(profile: profile)
                }
                if profile.tier == .departmentHead {
                    NavigationLink("Invite subordinates") {
                        ConsultantInvitationCockpitView(profile: profile)
                    }
                }
                departmentLinks(profile)
            }
            Section("SetOS command deck") {
                NavigationLink("PM · Executive matrix (zero chatter)") {
                    PMMacroMatrixView()
                }
                NavigationLink("Locations PA hub") {
                    LocationsPAHubView()
                }
                NavigationLink("Crisis split-screen matrix") {
                    CrisisSplitScreenView()
                }
                NavigationLink("Temporal 24h auth handoff") {
                    TemporalAuthHandoffView()
                }
                NavigationLink("Vita voice console") {
                    VitaVoiceConsoleView()
                }
                NavigationLink("Zoho · VitaLogic hub") {
                    ZohoAdvancedHubView()
                }
                NavigationLink("Transport shield · MTO ledger") {
                    TransportShieldConsoleView()
                }
                NavigationLink("Spatial guidance (Chantal → Wayne)") {
                    SpatialGuidanceConsoleView()
                }
                if profile.department == .costume || profile.tier == .departmentHead {
                    NavigationLink("Creative monitor feed") {
                        CreativeMonitorFeedView()
                    }
                }
            }
        }
        Section("Profiles") {
            ForEach(profiles) { p in
                Button {
                    selectedProfile = p
                    session.setActiveProfileID(p.id)
                } label: {
                    HStack {
                        Text(p.department.displayName)
                        Spacer()
                        if p.id == activeProfile?.id {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func departmentLinks(_ profile: ExpertConsultantProfile) -> some View {
        switch profile.department {
            case .transport:
                NavigationLink("Shuttle tracker") { LiveShuttleMapView() }
                NavigationLink("Fleet monitor") { TransportMasterDashboardView() }
                NavigationLink("Crisis command matrix") { CrisisSplitScreenView() }
                NavigationLink("Temporal captain handoff") { TemporalAuthHandoffView() }
            case .accounting:
                NavigationLink("AP · Payroll portal") { APPayrollPortalView() }
                NavigationLink("Approvals inbox") { ApprovalsInboxView() }
            case .costume:
                NavigationLink("Costume console") { CostumeConsoleView() }
            case .tadAD:
                NavigationLink("TAD logistics") { TADLogisticsDashboardView() }
                NavigationLink("AD floor wrap console") { ADFloorWrapConsoleView() }
            case .locations:
                NavigationLink("Locations PA hub") { LocationsPAHubView() }
                NavigationLink("Cube truck bumper sweep") { LocationsCubeTruckConsoleView() }
            default:
                NavigationLink("AD floor wrap console") { ADFloorWrapConsoleView() }
        }
    }

    private func exportPDF(_ profile: ExpertConsultantProfile) {
        let locked = ImmutableProfileLock.read(profile: profile)
        do {
            let url = try OnboardingPDFExportEngine.exportConsultantPackage(
                profile: profile,
                lockedFields: locked,
                legalTokenHash: profile.legalTokenHash
            )
            exportStatus = "Saved \(url.lastPathComponent)"
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            #endif
        } catch {
            exportStatus = error.localizedDescription
        }
    }

    private func seedHead() {
        do {
            let p = try ConsultantIngestionManager.seedCoordinatorProfile(
                context: modelContext,
                department: seedDepartment,
                productionTitle: productionTitle
            )
            session.setActiveProfileID(p.id)
            selectedProfile = p
        } catch {
            #if DEBUG
            print("Seed head failed: \(error)")
            #endif
        }
    }

    private func seedAccounting() {
        let p = ExpertConsultantProfile(
            department: .accounting,
            tier: .accountingVault,
            yearsOfExperience: 25,
            activeProductionTitle: productionTitle
        )
        p.tier = .accountingVault
        modelContext.insert(p)
        try? modelContext.save()
        session.setActiveProfileID(p.id)
        selectedProfile = p
    }

    private func lockProfile(_ profile: ExpertConsultantProfile) {
        let harvest = PageOneHarvestService.harvest(from: dealMemoOCR)
        ImmutableProfileLock.lock(
            profile: profile,
            fields: LockedConsultantFields(
                legalName: legalName,
                addressLine: address,
                corporateEntityName: harvest.corporateEntity,
                unionTier: harvest.unionTier,
                activeProductionTitle: productionTitle,
                hourlyRate: harvest.hourlyRate,
                kitAllowance: harvest.kitAllowance
            )
        )
        profile.activeProductionTitle = productionTitle
        try? modelContext.save()
    }
}
