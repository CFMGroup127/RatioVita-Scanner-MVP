import Foundation
import SwiftData

/// Ensures income / cheque **payors** (e.g. Bell Media Inc.) exist in the production contact graph.
@MainActor
enum PayorContactRegistry {
    struct Result: Sendable {
        var contact: ProductionContact
        var created: Bool
    }

    static func registerPayorIfNeeded(
        payorName: String?,
        payorAddress: String?,
        receipt: Receipt,
        context: ModelContext
    ) -> Result? {
        let name = payorName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let name, !name.isEmpty else { return nil }

        let ownedNames = ReceiptPersistence.fetchRegistryEntityLegalNames(context: context)
        if RegistryEntityPolarity.matchesRegistryEntity(
            merchant: name,
            payee: nil,
            supplementalOCR: nil,
            entityLegalNames: ownedNames
        ) {
            return nil
        }

        let contacts = (try? context.fetch(FetchDescriptor<ProductionContact>())) ?? []
        if let existing = contacts.first(where: { matches($0, name: name) }) {
            receipt.counterpartyContact = existing
            appendPayorNotes(to: existing, address: payorAddress, receipt: receipt)
            existing.updatedAt = .now
            return Result(contact: existing, created: false)
        }

        var lines = ["Harvested from cheque / income stub."]
        if let addr = payorAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("Address: \(addr)")
        }
        if let token = receipt.clientAccountingToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("Client accounting token: \(token)")
        }

        let contact = ProductionContact(
            name: name,
            companyName: name,
            tags: ["Payor", "Accounts receivable"],
            notes: lines.joined(separator: "\n")
        )
        context.insert(contact)
        receipt.counterpartyContact = contact
        return Result(contact: contact, created: true)
    }

    private static func matches(_ contact: ProductionContact, name: String) -> Bool {
        contact.name.caseInsensitiveCompare(name) == .orderedSame
            || (contact.companyName?.caseInsensitiveCompare(name) == .orderedSame)
    }

    private static func appendPayorNotes(
        to contact: ProductionContact,
        address: String?,
        receipt: Receipt
    ) {
        var add: [String] = []
        if let addr = address?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            if !(contact.notes ?? "").localizedCaseInsensitiveContains(addr) {
                add.append("Address: \(addr)")
            }
        }
        if let inv = receipt.internalInvoiceNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            add.append("Last invoice #: \(inv)")
        }
        guard !add.isEmpty else { return }
        let block = add.joined(separator: "\n")
        let prior = contact.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        contact.notes = prior.isEmpty ? block : "\(prior)\n\(block)"
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
