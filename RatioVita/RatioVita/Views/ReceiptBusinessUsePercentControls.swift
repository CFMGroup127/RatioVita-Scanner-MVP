import SwiftData
import SwiftUI

/// Shared 0…100% business-use editor (detail + macOS Review). Hidden for income-like document types.
struct ReceiptBusinessUsePercentControls: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @Bindable var receipt: Receipt
    var disabled: Bool = false

    private var showsSlider: Bool {
        switch DocumentTypeOption.fromStored(receipt.documentType) {
            case .incomeOrCheck, .outgoingInvoice, .paycheck, .statement, .canadianTaxSlip:
                false
            default:
                true
        }
    }

    var body: some View {
        if showsSlider {
            VStack(alignment: .leading, spacing: 8) {
                Text("For mixed personal / business spend (vehicles, equipment).")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
                if let s = receipt.businessUseSuggestedPercent {
                    Text("Suggested (time sheet): \(Int(s.rounded()))%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(Color.ratioVitaTextSecondary.opacity(0.9))
                }
                Slider(
                    value: Binding(
                        get: { receipt.businessUsePercent ?? 0 },
                        set: { newValue in
                            receipt.businessUsePercent = newValue
                            if let s = receipt.businessUseSuggestedPercent,
                               abs(s - newValue) > 0.5
                            {
                                receipt.businessUseVerifiedByTimeSheet = false
                            }
                            try? modelContext.save()
                        }
                    ),
                    in: 0...100,
                    step: 1,
                    label: { EmptyView() },
                    minimumValueLabel: { Text("0%") },
                    maximumValueLabel: { Text("100%") }
                )
                .tint(brandAccent)
                .disabled(disabled)
                HStack {
                    Text("\(Int((receipt.businessUsePercent ?? 0).rounded()))% business")
                        .font(DesignSystem.Typography.bodyEmphasized)
                    if receipt.businessUseVerifiedByTimeSheet {
                        Spacer()
                        Label("Verified by time sheet", systemImage: "checkmark.seal.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(Color.ratioVitaSuccess)
                    }
                }
            }
        }
    }
}
