import Foundation
import SwiftData

/// Links **outgoing invoices** (your AR) to a `ProductionContact` using client / production fields from extraction.
@MainActor
enum InvoiceClientContactHarvester {
    static func harvestIfNeeded(merged: ExtractedData, receipt: Receipt, context: ModelContext) {
        guard receipt.counterpartyContact == nil else { return }
        let clientName =
            merged.clientProductionCompany?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? merged.clientProjectTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? merged.payor?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? merged.payee?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let clientName, !clientName.isEmpty else { return }

        let fd = FetchDescriptor<ProductionContact>()
        let contacts = (try? context.fetch(fd)) ?? []
        if let existing = contacts.first(where: {
            $0.name.caseInsensitiveCompare(clientName) == .orderedSame
                || ($0.companyName?.caseInsensitiveCompare(clientName) == .orderedSame)
        }) {
            receipt.counterpartyContact = existing
            existing.updatedAt = .now
            appendInvoiceNotes(to: existing, merged: merged)
            return
        }

        var lines = ["Harvested from outgoing invoice OCR."]
        if let po = merged.purchaseOrderNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("PO: \(po)")
        }
        if let pm = merged.productionManagerName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("PM / contact: \(pm)")
        }
        if let show = merged.clientProjectTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("Project title: \(show)")
        }
        let contact = ProductionContact(
            name: clientName,
            companyName: merged.clientProductionCompany ?? clientName,
            tags: ["Invoice client", "Production billing"],
            notes: lines.joined(separator: "\n")
        )
        context.insert(contact)
        receipt.counterpartyContact = contact
    }

    private static func appendInvoiceNotes(to contact: ProductionContact, merged: ExtractedData) {
        var add: [String] = []
        if let po = merged.purchaseOrderNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            add.append("PO: \(po)")
        }
        if let pm = merged.productionManagerName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            add.append("PM: \(pm)")
        }
        if let t = merged.clientProjectTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            add.append("Project: \(t)")
        }
        guard !add.isEmpty else { return }
        let block = add.joined(separator: "\n")
        let prior = contact.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if prior.isEmpty {
            contact.notes = block
        } else if !prior.contains(block) {
            contact.notes = prior + "\n\n" + block
        }
        contact.updatedAt = .now
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
