import Foundation
import SwiftData

/// Resolves merchant / vendor strings against CRM + corporate registry for paste-to-fill workflows.
@MainActor
enum CounterpartyCRMLookup {
    struct Suggestion: Sendable {
        var vendorAddress: String?
        var gstHstNumber: String?
        var contact: ProductionContact?
        var businessEntity: BusinessEntity?
        var sourceLabel: String
    }

    static func suggest(forMerchant merchant: String, context: ModelContext) -> Suggestion? {
        let needle = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return nil }
        let lower = needle.lowercased()

        if let entity = matchBusinessEntity(lower: lower, context: context) {
            return Suggestion(
                vendorAddress: trimmedOptional(entity.businessAddress),
                gstHstNumber: trimmedOptional(entity.gstHstNumber),
                contact: nil,
                businessEntity: entity,
                sourceLabel: "Corporate registry"
            )
        }

        if let contact = matchProductionContact(lower: lower, context: context) {
            return Suggestion(
                vendorAddress: trimmedOptional(contact.notes),
                gstHstNumber: nil,
                contact: contact,
                businessEntity: nil,
                sourceLabel: "Production contact"
            )
        }

        if let prior = matchPriorReceiptVendor(lower: lower, context: context) {
            return prior
        }

        return nil
    }

    private static func matchBusinessEntity(lower: String, context: ModelContext) -> BusinessEntity? {
        let rows = (try? context.fetch(FetchDescriptor<BusinessEntity>())) ?? []
        return rows.first { row in
            let legal = row.legalName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !legal.isEmpty else { return false }
            return legal == lower || legal.contains(lower) || lower.contains(legal)
        }
    }

    private static func matchProductionContact(lower: String, context: ModelContext) -> ProductionContact? {
        let rows = (try? context.fetch(FetchDescriptor<ProductionContact>())) ?? []
        return rows.first { row in
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let co = row.companyName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if name == lower || co == lower { return true }
            if !co.isEmpty, co.contains(lower) || lower.contains(co) { return true }
            if !name.isEmpty, name.contains(lower) || lower.contains(name) { return true }
            return false
        }
    }

    private static func matchPriorReceiptVendor(lower: String, context: ModelContext) -> Suggestion? {
        let rows = (try? context.fetch(FetchDescriptor<Receipt>())) ?? []
        guard let hit = rows.first(where: { r in
            let m = r.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard m == lower || m.contains(lower) || lower.contains(m) else { return false }
            let addr = r.vendorAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !addr.isEmpty
        }) else { return nil }

        return Suggestion(
            vendorAddress: trimmedOptional(hit.vendorAddress),
            gstHstNumber: nil,
            contact: hit.counterpartyContact,
            businessEntity: nil,
            sourceLabel: "Prior receipt"
        )
    }

    private static func trimmedOptional(_ raw: String?) -> String? {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
}
