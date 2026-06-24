import Foundation

/// Decoupled-ledger visibility — filters receipts, line items, and scoped totals by active sovereign hub.
enum SovereignScopeFilter {

    // MARK: - Receipt visibility

    /// Whether a receipt (or any of its lines) belongs in the active hub's ledgers.
    static func receiptIsVisible(_ receipt: Receipt, context: SovereignContextManager) -> Bool {
        receiptIsVisible(
            receipt,
            hub: context.activeHub,
            ventureEntityID: context.activeVentureEntityID,
            productionID: context.isolationProductionID
        )
    }

    static func receiptIsVisible(
        _ receipt: Receipt,
        hub: SovereignHubKind,
        ventureEntityID: UUID?,
        productionID: UUID?
    ) -> Bool {
        let lines = receipt.lineItems
        if !lines.isEmpty {
            return lines.contains { lineMatchesScope($0, hub: hub, ventureEntityID: ventureEntityID, productionID: productionID) }
        }
        return receiptLevelMatchesScope(receipt, hub: hub, ventureEntityID: ventureEntityID, productionID: productionID)
    }

    /// Triage queue: show master blocks with unrouted lines everywhere; routed lines respect hub isolation.
    static func triageReceiptIsVisible(_ receipt: Receipt, context: SovereignContextManager) -> Bool {
        let lines = receipt.lineItems
        if lines.isEmpty {
            return receiptLevelMatchesScope(receipt, hub: context.activeHub, ventureEntityID: context.activeVentureEntityID, productionID: context.isolationProductionID)
                || context.activeHub == .personal
        }
        if lines.contains(where: { lineIsUnallocated($0) }) {
            return true
        }
        return receiptIsVisible(receipt, context: context)
    }

    static func filterReceipts(_ receipts: [Receipt], context: SovereignContextManager) -> [Receipt] {
        receipts.filter { receiptIsVisible($0, context: context) }
    }

    // MARK: - Line scoping

    static func lineMatchesScope(
        _ line: ReceiptLineItem,
        context: SovereignContextManager
    ) -> Bool {
        lineMatchesScope(
            line,
            hub: context.activeHub,
            ventureEntityID: context.activeVentureEntityID,
            productionID: context.isolationProductionID
        )
    }

    static func lineMatchesScope(
        _ line: ReceiptLineItem,
        hub: SovereignHubKind,
        ventureEntityID: UUID?,
        productionID: UUID?
    ) -> Bool {
        if lineIsUnallocated(line) {
            return hub == .personal
        }
        if line.allocationIsPersonal {
            return hub == .personal
        }
        if let project = line.allocatedProductionProject {
            switch hub {
            case .personal:
                return false
            case .ventures:
                if let ventureEntityID {
                    return project.businessEntity?.id == ventureEntityID
                }
                return project.businessEntity != nil
            case .production:
                guard let productionID else { return true }
                return project.id == productionID
            }
        }
        if let entity = line.allocatedBusinessEntity {
            switch hub {
            case .personal:
                return false
            case .ventures:
                if let ventureEntityID {
                    return entity.id == ventureEntityID
                }
                return true
            case .production:
                return false
            }
        }
        return hub == .personal
    }

    static func lineIsUnallocated(_ line: ReceiptLineItem) -> Bool {
        !line.allocationIsPersonal
            && line.allocatedBusinessEntity == nil
            && line.allocatedProductionProject == nil
    }

    // MARK: - Scoped financial totals

    /// Pre-tax amount attributed to the active hub (for split receipts).
    static func scopedPreTaxTotal(for receipt: Receipt, context: SovereignContextManager) -> Decimal {
        scopedPreTaxTotal(
            for: receipt,
            hub: context.activeHub,
            ventureEntityID: context.activeVentureEntityID,
            productionID: context.isolationProductionID
        )
    }

    static func scopedPreTaxTotal(
        for receipt: Receipt,
        hub: SovereignHubKind,
        ventureEntityID: UUID?,
        productionID: UUID?
    ) -> Decimal {
        let lines = receipt.lineItems
        if !lines.isEmpty {
            return lines
                .filter { lineMatchesScope($0, hub: hub, ventureEntityID: ventureEntityID, productionID: productionID) }
                .map { ReceiptLineItemAllocationEngine.preTaxAmount(for: $0) }
                .reduce(0, +)
        }
        guard receiptLevelMatchesScope(receipt, hub: hub, ventureEntityID: ventureEntityID, productionID: productionID) else {
            return 0
        }
        if hub == .personal, let pct = receipt.businessUsePercent, pct < 100, pct > 0 {
            return receipt.total * Decimal(pct / 100)
        }
        return receipt.subtotalAmount ?? receipt.total
    }

    static func scopedDisplayTotal(for receipt: Receipt, context: SovereignContextManager) -> Decimal {
        let preTax = scopedPreTaxTotal(for: receipt, context: context)
        let lines = receipt.lineItems
        guard !lines.isEmpty, preTax > 0 else {
            return scopedPreTaxTotal(for: receipt, context: context)
        }
        let receiptPreTax = max(receipt.subtotalAmount ?? receipt.total, 0)
        guard receiptPreTax > 0, receiptPreTax != preTax else { return preTax }
        let tax = receipt.taxAmount ?? 0
        let ratio = preTax / receiptPreTax
        return preTax + (tax * ratio)
    }

    // MARK: - Bank reconciliation

    static func bankTransactionIsVisible(_ tx: BankTransaction, context: SovereignContextManager, openReceipts: [Receipt]) -> Bool {
        if let matched = tx.matchedReceipt {
            return receiptIsVisible(matched, context: context)
        }
        switch context.activeHub {
        case .personal:
            return true
        case .ventures, .production:
            return openReceipts.contains { receipt in
                receiptIsVisible(receipt, context: context)
                    && receipt.currencyCode.caseInsensitiveCompare(tx.currencyCode) == .orderedSame
            }
        }
    }

    // MARK: - Private

    private static func receiptLevelMatchesScope(
        _ receipt: Receipt,
        hub: SovereignHubKind,
        ventureEntityID: UUID?,
        productionID: UUID?
    ) -> Bool {
        switch hub {
        case .personal:
            if receipt.productionProject != nil { return false }
            if let pct = receipt.businessUsePercent, pct >= 100 { return false }
            return true
        case .ventures:
            guard let project = receipt.productionProject else {
                return ventureEntityID == nil && (receipt.businessUsePercent ?? 0) > 0
            }
            if let ventureEntityID {
                return project.businessEntity?.id == ventureEntityID
            }
            return project.businessEntity != nil || receipt.businessUsePercent ?? 0 > 0
        case .production:
            guard let productionID else { return receipt.productionProject != nil }
            return receipt.productionProject?.id == productionID
        }
    }
}
