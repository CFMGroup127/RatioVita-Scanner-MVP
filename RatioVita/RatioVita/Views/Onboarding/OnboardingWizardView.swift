import SwiftUI

/// Linear white-glove onboarding — no dashboard until step 8 completes (Sprint JJJJ).
@MainActor
struct OnboardingWizardView: View {
    @ObservedObject private var coordinator = SetOSOnboardingCoordinator.shared
    @ObservedObject private var sandbox = SandboxEnvironmentController.shared

    var onFinished: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                Divider()
                ScrollView {
                    stepContent
                        .padding(DesignSystem.Spacing.lg)
                }
                Divider()
                navigationFooter
                    .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("RatioVita")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if coordinator.currentStep.rawValue > 1 {
                            Button("Back") {
                                coordinator.goBack()
                                coordinator.persistDraft()
                            }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(true)
    }

    private var progressHeader: some View {
        VStack(spacing: 6) {
            Text("Core onboarding · Step \(coordinator.currentStep.rawValue) of 8")
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(coordinator.currentStep.title)
                .font(.headline)
            ProgressView(value: Double(coordinator.currentStep.rawValue), total: 8)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch coordinator.currentStep {
            case .legalAgreements:
                legalStep
            case .personalRegistration:
                personalStep
            case .sideHustleSetup:
                sideHustleStep
            case .productionContext:
                productionContextStep
            case .showCodeEntry:
                showCodeStep
            case .departmentSelection:
                departmentStep
            case .positionSelection:
                positionStep
            case .widgetConfiguration:
                widgetStep
        }
    }

    private var legalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Legal clearances")
                .font(.title2.bold())
            Text(
                "Review and accept the Terms of Service, Non-Disclosure Agreement (NDA), and Non-Compete (NCA) before any vault or production data is unlocked."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(LegalShieldGatekeeper.standardTerms) { term in
                        Text(term.title)
                            .font(.subheadline.weight(.semibold))
                        Text(term.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.ratioVitaAdaptiveSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxHeight: 220)

            Toggle("I accept the Terms of Service", isOn: $coordinator.acceptedTerms)
            Toggle("I accept the Non-Disclosure Agreement (NDA)", isOn: $coordinator.acceptedNDA)
            Toggle("I accept the Non-Compete Agreement (NCA)", isOn: $coordinator.acceptedNCA)
        }
    }

    private var personalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal registration")
                .font(.title2.bold())
            Text("Your sovereign identity slice — used for payroll matching and personal finance modules.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Legal name", text: $coordinator.legalName)
                .textFieldStyle(.roundedBorder)
            Text("Mailing address")
                .font(.caption)
                .foregroundStyle(.secondary)
            StandardizedAddressStringEditor(rawAddress: $coordinator.mailingAddress)
            TextField("Phone", text: $coordinator.phoneLine)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .textContentType(.telephoneNumber)
            #endif
        }
    }

    private var sideHustleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Side businesses")
                .font(.title2.bold())
            Text(
                "Register corporations, agencies, or rental houses you operate. This unlocks Quadrant 2 widgets without mixing them into your show tools."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Toggle("I operate a side business (invoices, inventory, Zoho Books)", isOn: $coordinator.sideHustleEnabled)
            if coordinator.sideHustleEnabled {
                Toggle("Enable side-hustle home-screen quadrant", isOn: Binding(
                    get: { coordinator.enabledQuadrants.contains(.sideHustle) },
                    set: { on in
                        if on { coordinator.enabledQuadrants.insert(.sideHustle) }
                        else { coordinator.enabledQuadrants.remove(.sideHustle) }
                    }
                ))
            }
        }
    }

    private var productionContextStep: some View {
        VStack(spacing: 20) {
            Text("Active production")
                .font(.title2.bold())
            Text("Are you currently working on a live, registered production?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Yes — join active show") {
                coordinator.onActiveProduction = true
                coordinator.sandboxMode = false
                coordinator.advance()
                coordinator.persistDraft()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("No — launch sandbox & personal hub") {
                coordinator.skipToSandbox()
                coordinator.persistDraft()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Text(
                "Freelance PMs and coordinators can practice in sandbox months before a show subscribes — then enter a show code when ready."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var showCodeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Production token")
                .font(.title2.bold())
            TextField("Unique show code (e.g. NETFLIX-873-S7)", text: $coordinator.showCode)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            #if os(iOS)
                .textInputAutocapitalization(.characters)
            #endif
            TextField("Production title (display)", text: $coordinator.productionTitle)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var departmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select your department")
                .font(.title2.bold())
            Text("Only your department bucket is shown — no mixed union lists.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Department", selection: $coordinator.selectedDepartmentName) {
                Text("Choose department…").tag("")
                ForEach(DepartmentHierarchyRegistry.departments) { dept in
                    Text(dept.name).tag(dept.name)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .onChange(of: coordinator.selectedDepartmentName) { _, _ in
                coordinator.selectedPositionTitle = ""
            }
        }
    }

    private var positionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select your position")
                .font(.title2.bold())

            if coordinator.selectedDepartmentName.isEmpty {
                Text("Select a department first.")
                    .foregroundStyle(.secondary)
            } else {
                let positions = DepartmentHierarchyRegistry.positions(
                    forDepartmentNamed: coordinator.selectedDepartmentName
                )
                Picker("Position", selection: $coordinator.selectedPositionTitle) {
                    Text("Choose position…").tag("")
                    ForEach(positions) { pos in
                        Text(pos.title).tag(pos.title)
                    }
                }
                #if os(iOS)
                .pickerStyle(.wheel)
                #endif

                if let position = coordinator.activePosition {
                    Text("Rank: \(position.rankTier.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var widgetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home screen & dock widgets")
                .font(.title2.bold())
            Text(
                "Pin the tiles you want on your device home screen. The main RatioVita hub stays in the background — tap a widget to log timecards or department tools directly."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if coordinator.sandboxMode {
                Label(sandbox.statusMessage ?? "Sandbox ready", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            IsolatedWidgetPickerView(coordinator: coordinator)

            Text(TimecardWidgetTimelineProvider.shared.buildTimelineSummary())
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var navigationFooter: some View {
        switch coordinator.currentStep {
            case .legalAgreements:
                Button("Continue to personal profile") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!coordinator.legalGateSatisfied)
                .frame(maxWidth: .infinity)
            case .personalRegistration:
                Button("Continue") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!coordinator.personalGateSatisfied)
                .frame(maxWidth: .infinity)
            case .sideHustleSetup:
                Button("Continue") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            case .productionContext:
                EmptyView()
            case .showCodeEntry:
                Button("Verify & continue") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.showCode.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(maxWidth: .infinity)
            case .departmentSelection:
                Button("Next: position") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.selectedDepartmentName.isEmpty)
                .frame(maxWidth: .infinity)
            case .positionSelection:
                Button("Next: widgets") {
                    coordinator.advance()
                    coordinator.persistDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.selectedPositionTitle.isEmpty)
                .frame(maxWidth: .infinity)
            case .widgetConfiguration:
                Button("Finish & enter RatioVita") {
                    coordinator.finalizeOnboarding()
                    onFinished?()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }
}
