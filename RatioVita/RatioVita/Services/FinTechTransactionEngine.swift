import Foundation
import SwiftData

/// Craft-truck wallet taps and New Horizons batch checkout with automated tip cascade.
@MainActor
enum FinTechTransactionEngine {
    struct TipCascadeShares: Sendable {
        var serverCAD: Decimal
        var bartenderCAD: Decimal
        var supportCAD: Decimal

        var total: Decimal { serverCAD + bartenderCAD + supportCAD }
    }

    struct BatchCheckoutResult: Sendable {
        var sessionID: UUID
        var foodSubtotalCAD: Decimal
        var gratuityCAD: Decimal
        var tipShares: TipCascadeShares
        var paymentReference: String
    }

    /// Simulates Apple Wallet / QR capture for a host paying an entire party tab.
    static func processBatchGuestCards(
        context: ModelContext,
        hostName: String,
        cardIdentifiers: [String],
        totalAmount: Decimal,
        gratuityAmount: Decimal,
        serverPercent: Double = 60,
        bartenderPercent: Double = 25,
        supportPercent: Double = 15
    ) throws -> BatchCheckoutResult {
        let foodSubtotal = max(0, totalAmount - gratuityAmount)
        let shares = distributeTip(
            gratuity: gratuityAmount,
            serverPercent: serverPercent,
            bartenderPercent: bartenderPercent,
            supportPercent: supportPercent
        )
        let session = VenueCheckoutSession(
            hostName: hostName,
            guestCardIdentifiers: cardIdentifiers,
            foodSubtotalCAD: foodSubtotal,
            gratuityCAD: gratuityAmount,
            tipServerShareCAD: shares.serverCAD,
            tipBartenderShareCAD: shares.bartenderCAD,
            tipSupportShareCAD: shares.supportCAD
        )
        session.clearedAt = .now
        context.insert(session)
        try context.save()

        let ref = "RV-NH-\(session.id.uuidString.prefix(8).uppercased())"
        return BatchCheckoutResult(
            sessionID: session.id,
            foodSubtotalCAD: foodSubtotal,
            gratuityCAD: gratuityAmount,
            tipShares: shares,
            paymentReference: ref
        )
    }

    /// Off-list craft retail (Red Bull, etc.) — routes to production ledger or crew wallet.
    static func recordCraftMicroPurchase(
        context: ModelContext,
        itemTitle: String,
        amountCAD: Decimal,
        paidByProduction: Bool,
        crewMemberName: String,
        walletTapReference: String? = nil
    ) throws -> CraftMicroPurchase {
        let purchase = CraftMicroPurchase(
            itemTitle: itemTitle,
            amountCAD: amountCAD,
            paidByProduction: paidByProduction,
            crewMemberName: crewMemberName,
            walletTransactionRef: walletTapReference ?? "WALLET-TAP-\(UUID().uuidString.prefix(8))"
        )
        context.insert(purchase)
        try context.save()
        return purchase
    }

    static func distributeTip(
        gratuity: Decimal,
        serverPercent: Double = 60,
        bartenderPercent: Double = 25,
        supportPercent: Double = 15
    ) -> TipCascadeShares {
        guard gratuity > 0 else {
            return TipCascadeShares(serverCAD: 0, bartenderCAD: 0, supportCAD: 0)
        }
        let totalPct = serverPercent + bartenderPercent + supportPercent
        let norm = totalPct > 0 ? totalPct : 100
        let server = roundCurrency(gratuity * Decimal(serverPercent / norm))
        let bartender = roundCurrency(gratuity * Decimal(bartenderPercent / norm))
        let support = gratuity - server - bartender
        return TipCascadeShares(serverCAD: server, bartenderCAD: bartender, supportCAD: support)
    }

    private static func roundCurrency(_ value: Decimal) -> Decimal {
        var rounded = value
        var asDouble = (value as NSDecimalNumber).doubleValue
        asDouble = (asDouble * 100).rounded() / 100
        rounded = Decimal(asDouble)
        return rounded
    }
}
