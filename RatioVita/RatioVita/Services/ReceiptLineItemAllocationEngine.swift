import Foundation

/// Weighted proportional HST routing across business entities (CRA mixed-use method).
enum ReceiptLineItemAllocationEngine {
    struct EntityTaxShare: Identifiable, Equatable {
        var id: UUID { entityID }
        var entityID: UUID
        var legalName: String
        var preTaxAllocated: Decimal
        var taxShare: Decimal
        var shareOfSubtotal: Double
    }

    struct Summary: Equatable {
        var receiptSubtotal: Decimal
        var allocatedPreTax: Decimal
        var unallocatedPreTax: Decimal
        var totalTax: Decimal
        var entityShares: [EntityTaxShare]
        var personalPreTax: Decimal
        var personalTaxShare: Decimal
        var personalShareOfSubtotal: Double
    }

    static func preTaxAmount(for line: ReceiptLineItem) -> Decimal {
        if let total = line.totalPrice, total > 0 { return total }
        if let unit = line.unitPrice, let qty = line.quantity, qty > 0 {
            return unit * Decimal(qty)
        }
        if let unit = line.unitPrice { return unit }
        return 0
    }

    static func summarize(
        lines: [ReceiptLineItem],
        receiptSubtotal: Decimal?,
        receiptTax: Decimal?
    ) -> Summary {
        let subtotal = max(receiptSubtotal ?? lines.map { preTaxAmount(for: $0) }.reduce(0, +), 0)
        let totalTax = max(receiptTax ?? 0, 0)

        var byEntity: [UUID: (name: String, sum: Decimal)] = [:]
        var personalSum: Decimal = 0
        var allocated: Decimal = 0

        for line in lines {
            let amt = preTaxAmount(for: line)
            guard amt > 0 else { continue }
            if line.allocationIsPersonal == true {
                personalSum += amt
                allocated += amt
            } else if let entity = line.allocatedBusinessEntity {
                allocated += amt
                var bucket = byEntity[entity.id] ?? (entity.legalName, 0)
                bucket.sum += amt
                byEntity[entity.id] = bucket
            }
        }

        let unallocated = max(subtotal - allocated, 0)
        let personalTotal = personalSum + unallocated
        let denominator = subtotal > 0 ? subtotal : Decimal(1)

        var shares: [EntityTaxShare] = []
        for (id, bucket) in byEntity.sorted(by: { $0.value.name < $1.value.name }) {
            let ratio = NSDecimalNumber(decimal: bucket.sum / denominator).doubleValue
            let taxShare = totalTax * bucket.sum / denominator
            shares.append(
                EntityTaxShare(
                    entityID: id,
                    legalName: bucket.name,
                    preTaxAllocated: bucket.sum,
                    taxShare: taxShare,
                    shareOfSubtotal: ratio
                )
            )
        }

        let personalRatio = NSDecimalNumber(decimal: personalTotal / denominator).doubleValue
        let personalTax = totalTax * personalTotal / denominator

        return Summary(
            receiptSubtotal: subtotal,
            allocatedPreTax: allocated,
            unallocatedPreTax: unallocated,
            totalTax: totalTax,
            entityShares: shares,
            personalPreTax: personalTotal,
            personalTaxShare: personalTax,
            personalShareOfSubtotal: personalRatio
        )
    }

    static func auditDetail(summary: Summary) -> String {
        var parts: [String] = [
            "Subtotal \(summary.receiptSubtotal)",
            "Tax \(summary.totalTax)",
        ]
        for s in summary.entityShares {
            parts.append("\(s.legalName): pre-tax \(s.preTaxAllocated), HST \(s.taxShare)")
        }
        if summary.personalPreTax > 0 {
            parts.append("Personal: pre-tax \(summary.personalPreTax), HST \(summary.personalTaxShare)")
        }
        if summary.unallocatedPreTax > 0 {
            parts.append("Unallocated remainder → personal: \(summary.unallocatedPreTax)")
        }
        return parts.joined(separator: " · ")
    }
}
