import SwiftUI

/// Transport Coordinator liability + MTO pre-flight deck (Sprint KKKK).
struct TransportShieldConsoleView: View {
    @StateObject private var ledger = TransportLiabilityLedger.shared
    @StateObject private var mto = MTOCircleCheckEngine.shared

    @State private var clearanceUnionID = ""
    @State private var clearanceLocal: TransportUnionLocal = .teamsters
    @State private var clearanceVerdict: DriverClearanceVerdict?

    var body: some View {
        Form {
            if let banner = mto.activeBanner {
                Section {
                    Label(banner, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline.weight(.semibold))
                }
            }

            clearanceSection
            circleCheckSection
            passportSection
            violationSection
        }
        .navigationTitle("Transport shield")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Driver clearance crosswalk

    private var clearanceSection: some View {
        Section("Driver clearance crosswalk") {
            Picker("Union local", selection: $clearanceLocal) {
                ForEach(TransportUnionLocal.allCases, id: \.self) { local in
                    Text(local.rawValue).tag(local)
                }
            }
            TextField("Union ID number", text: $clearanceUnionID)
            #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            #endif

            Button("Run pre-authorization check") {
                clearanceVerdict = ledger.clearanceCheck(
                    unionLocal: clearanceLocal,
                    unionID: clearanceUnionID.trimmingCharacters(in: .whitespaces)
                )
            }
            .disabled(clearanceUnionID.trimmingCharacters(in: .whitespaces).isEmpty)

            if let verdict = clearanceVerdict {
                if verdict.cleared {
                    Label(
                        "Cleared for assignment\(verdict.matchedRecord.map { " — \($0.fullName)" } ?? "")",
                        systemImage: "checkmark.seal.fill"
                    )
                    .foregroundStyle(.green)
                } else if let banner = verdict.hazardBanner {
                    Label(banner, systemImage: "hand.raised.fill")
                        .foregroundStyle(.red)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Circle checks

    private var circleCheckSection: some View {
        Section("MTO circle checks") {
            if mto.records.isEmpty {
                Text("No circle checks opened today.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            ForEach(mto.records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.licensePlate)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if record.isSigned {
                            Label("Signed", systemImage: "signature")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Lockout", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("Driver \(record.driverUnionID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !record.isSigned {
                        Button("Sign circle check (clear to move)") {
                            mto.signCircleCheck(recordID: record.id)
                        }
                        .font(.footnote)
                    }
                }
            }

            Button("Demo · open + simulate early movement") {
                runMovementDemo()
            }
            .font(.footnote)
        }
    }

    // MARK: - Vehicle passports

    private var passportSection: some View {
        Section("Vehicle safety passports") {
            ForEach(ledger.passports) { passport in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(passport.licensePlate)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if passport.cvorStatusValid {
                            Label("CVOR", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    if !passport.makeModel.isEmpty {
                        Text("\(passport.makeModel) · \(passport.color)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if passport.hasOpenLiability {
                        Label(
                            passport.activeMechanicalFaults.joined(separator: ", "),
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    if !passport.unalterableIncidentHistory.isEmpty {
                        DisclosureGroup("Immutable history (\(passport.unalterableIncidentHistory.count))") {
                            ForEach(passport.unalterableIncidentHistory, id: \.self) { entry in
                                Text(entry)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private var violationSection: some View {
        Group {
            if !mto.violations.isEmpty {
                Section("Pre-flight security events") {
                    ForEach(mto.violations) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.summary)
                                .font(.footnote)
                                .foregroundStyle(.red)
                            Text(event.detectedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func runMovementDemo() {
        guard let vehicle = ledger.passports.first else { return }
        let check = mto.beginCircleCheck(
            vehicleID: vehicle.id,
            licensePlate: vehicle.licensePlate,
            driverUnionID: "T-88123"
        )
        _ = check
        // Vehicle rolls before the check is signed → lockout breach.
        mto.reportMovement(
            vehicleID: vehicle.id,
            licensePlate: vehicle.licensePlate,
            driverUnionID: "T-88123",
            metersMoved: 12.0
        )
    }
}
