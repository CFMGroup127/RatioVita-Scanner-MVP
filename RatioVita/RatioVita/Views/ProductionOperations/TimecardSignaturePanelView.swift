import SwiftData
import SwiftUI

/// Sovereignty signature panel — tap the box matching your role (right pane).
struct TimecardSignaturePanelView: View {
    @Environment(\.modelContext) private var modelContext

    let day: CrewTimecardDay
    let rules: ProductionApprovalRule

    @State private var statusMessage: String?
    @State private var isSigning = false

    private var nextBox: TimecardApprovalService.SignatureBox? {
        TimecardApprovalService.nextActionableBox(day: day, rules: rules)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Sovereignty signature panel")
                    .font(.headline)
                Text(
                    "Each timecard requires its own approval set. Tap the box for your role — saved initials from payroll compliance are applied automatically."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let nextBox {
                    Label("Next: \(nextBox.menuTitle)", systemImage: "hand.tap")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label("All required boxes signed", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                ForEach(TimecardApprovalService.SignatureBox.allCases, id: \.self) { box in
                    signatureBoxButton(box)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(width: SafeLayoutBounds.signaturePanelWidth)
    }

    private func signatureBoxButton(_ box: TimecardApprovalService.SignatureBox) -> some View {
        let state = TimecardApprovalService.boxStates(for: day)[box]
            ?? TimecardApprovalService.BoxState()
        let preview = state.initials ?? TimecardApprovalService.initialsForBox(box)
        let isNext = nextBox == box
        let isDone = state.isComplete

        return Button {
            Task { await sign(box: box) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(box.menuTitle)
                        .font(.subheadline.weight(.semibold))
                    if isDone, let signed = state.signedAt {
                        Text("Signed \(signed.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if isNext {
                        Text("Tap to sign with biometrics")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Awaiting prior boxes")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(preview.isEmpty ? "…" : preview)
                    .font(.title2.weight(.bold))
                    .frame(width: FixedColumnWidths.approvalBoxWidth, height: FixedColumnWidths.approvalBoxHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isDone ? Color.green.opacity(0.12) : Color.ratioVitaAdaptiveSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isNext ? Color.orange : Color.secondary.opacity(0.35), lineWidth: isNext ? 2 : 1)
                    )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(Color.ratioVitaAdaptiveSurface.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSigning || isDone || (nextBox != nil && nextBox != box))
    }

    private func sign(box: TimecardApprovalService.SignatureBox) async {
        isSigning = true
        defer { isSigning = false }
        let ok = await BiometricApprovalGate.confirm(
            reason: "Sign \(box.menuTitle) for \(day.workDate.formatted(date: .abbreviated, time: .omitted))"
        )
        guard ok else {
            await MainActor.run {
                statusMessage = "Biometric confirmation cancelled."
            }
            return
        }
        await MainActor.run {
            do {
                try TimecardApprovalService.signBox(
                    day: day,
                    box: box,
                    rules: rules,
                    context: modelContext
                )
                statusMessage = "\(box.menuTitle) box signed with \(TimecardApprovalService.initialsForBox(box))."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
