import SwiftUI

struct FXVarianceSummaryCard: View {
    let summary: FXVarianceSummary
    let fxSpread: Decimal
    let showsSpreadHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("FX settlement summary")
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(Color.ratioVitaAdaptiveText)

            row(
                "Invoice amount",
                CurrencyFormatter.shared.format(summary.foreignAmount, currencyCode: summary.foreignCurrency)
            )
            row(
                "Bank debit",
                CurrencyFormatter.shared.format(summary.actualBankDebit, currencyCode: summary.homeCurrency)
            )

            if summary.explicitWireFee > .zero {
                row(
                    "Wire fee",
                    CurrencyFormatter.shared.format(summary.explicitWireFee, currencyCode: summary.homeCurrency)
                )
            }

            row(
                "Implied exchange rate",
                FXVarianceCalculator.impliedRateLabel(
                    summary.impliedExchangeRate,
                    homeCurrency: summary.homeCurrency,
                    foreignCurrency: summary.foreignCurrency
                )
            )

            if fxSpread != .zero || summary.explicitWireFee > .zero {
                let spreadLabel = fxSpread > .zero ? "FX loss / spread" : "FX gain"
                row(
                    spreadLabel,
                    CurrencyFormatter.shared.format(abs(fxSpread), currencyCode: summary.homeCurrency)
                )
            } else if showsSpreadHint {
                Text("Enter a book / budget FX rate to calculate spread vs your expected home-currency cost.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(Color.ratioVitaTextSecondary)
            }

            Text(
                FXVarianceLedgerManager.generateVarianceDescription(
                    foreignCurrency: summary.foreignCurrency,
                    homeCurrency: summary.homeCurrency,
                    varianceAmount: fxSpread,
                    wireFee: summary.explicitWireFee,
                    impliedRate: summary.impliedExchangeRate
                )
            )
            .font(DesignSystem.Typography.caption2)
            .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(Color.ratioVitaAdaptiveBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .stroke(Color.ratioVitaInfo.opacity(0.35), lineWidth: 1)
        )
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodyEmphasized)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
        }
    }
}
