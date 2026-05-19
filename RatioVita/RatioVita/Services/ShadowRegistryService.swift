import Foundation
import SwiftData

/// **Forensic Shadow Registry** — provisional corporate profiles and Arctic Vault pre-sort before official onboarding.
@MainActor
enum ShadowRegistryService {
    static let auditKindShadowDiscovered = "corporate.shadow.discovered"
    static let auditKindShadowBulkMerge = "corporate.shadow.bulk_merge"

    static func fetchActiveShadowLegalNames(context: ModelContext) -> [String] {
        let fd = FetchDescriptor<PreliminaryBusinessEntity>()
        return (try? context.fetch(fd))?
            .filter { $0.mergedIntoBusinessEntity == nil }
            .map(\.detectedLegalName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    static func matchingShadow(
        forLegalName name: String,
        context: ModelContext
    ) -> PreliminaryBusinessEntity? {
        let key = PreliminaryBusinessEntity.makeNormalizedKey(from: name)
        guard !key.isEmpty else { return nil }
        let fd = FetchDescriptor<PreliminaryBusinessEntity>()
        let rows = (try? context.fetch(fd)) ?? []
        return rows.first { row in
            row.mergedIntoBusinessEntity == nil
                && (row.normalizedKey == key
                    || row.normalizedKey.contains(key)
                    || key.contains(row.normalizedKey))
        }
    }

    static func findOrCreateShadow(
        payeeName: String,
        address: String?,
        context: ModelContext
    ) throws -> PreliminaryBusinessEntity? {
        let trimmed = payeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let official = ReceiptPersistence.fetchRegistryEntityLegalNames(context: context)
        if RegistryEntityPolarity.matchesEntityName(trimmed, in: official) {
            return nil
        }

        if let existing = matchingShadow(forLegalName: trimmed, context: context) {
            if let addr = address?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty,
               (existing.businessAddress ?? "").isEmpty
            {
                existing.businessAddress = addr
                existing.updatedAt = .now
            }
            return existing
        }

        let key = PreliminaryBusinessEntity.makeNormalizedKey(from: trimmed)
        guard !key.isEmpty else { return nil }

        let shadow = PreliminaryBusinessEntity(
            detectedLegalName: trimmed,
            normalizedKey: key,
            businessAddress: address?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notes: "Auto-discovered from payee on check / invoice."
        )
        context.insert(shadow)
        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: auditKindShadowDiscovered,
            title: "Shadow entity discovered",
            detail: "shadow:\(shadow.id.uuidString)|\(trimmed)"
        )
        return shadow
    }

    /// Links receipt to shadow / official vault, applies payee-led filing, and harvests payor contacts.
    static func applyForensicAssociations(
        receipt: Receipt,
        merged: ExtractedData,
        supplementalOCR: String?,
        context: ModelContext
    ) throws {
        let payee = merged.payee?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let payor = merged.payor?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let payorAddr = merged.payorAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        receipt.payeeName = payee
        receipt.payorName = payor

        let officialNames = ReceiptPersistence.fetchRegistryEntityLegalNames(context: context)
        let shadowNames = fetchActiveShadowLegalNames(context: context)
        let polarityNames = officialNames + shadowNames

        let enforcedKind = RegistryEntityPolarity.enforcedRegistryIncomeDocumentKind(
            documentKind: merged.documentKind,
            merchant: merged.merchant,
            payee: payee,
            payor: payor,
            supplementalOCR: supplementalOCR,
            entityLegalNames: polarityNames
        )

        if enforcedKind == "income", let payor, !payor.isEmpty {
            receipt.merchant = payor
            CheckContactHarvester.harvestPayorIfNeeded(
                payorName: payor,
                payorAddress: payorAddr ?? merged.vendorAddress,
                receipt: receipt,
                context: context
            )
        } else if enforcedKind == "outgoing_invoice" {
            InvoiceClientContactHarvester.harvestIfNeeded(merged: merged, receipt: receipt, context: context)
        }

        let vaultPayee = payee ?? (enforcedKind == "income" ? merged.merchant : nil)
        guard let vaultPayee, !vaultPayee.isEmpty else {
            try matchExistingShadowByMerchantOrPayee(receipt: receipt, merged: merged, context: context)
            return
        }

        if RegistryEntityPolarity.matchesEntityName(vaultPayee, in: officialNames) {
            applyVaultPrefixIfEmpty(receipt: receipt, prefix: ReceiptVaultPathing.sanitizePathSegment(vaultPayee))
            return
        }

        if let shadow = try findOrCreateShadow(payeeName: vaultPayee, address: merged.vendorAddress, context: context) {
            receipt.preliminaryBusinessEntity = shadow
            applyVaultPrefixIfEmpty(receipt: receipt, prefix: shadow.vaultPathPrefix)
        }

        try matchExistingShadowByMerchantOrPayee(receipt: receipt, merged: merged, context: context)
    }

    private static func matchExistingShadowByMerchantOrPayee(
        receipt: Receipt,
        merged: ExtractedData,
        context: ModelContext
    ) throws {
        guard receipt.preliminaryBusinessEntity == nil else { return }
        let candidates = [merged.payee, merged.merchant, merged.payor, receipt.merchant]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        for name in candidates {
            if let shadow = matchingShadow(forLegalName: name, context: context) {
                receipt.preliminaryBusinessEntity = shadow
                applyVaultPrefixIfEmpty(receipt: receipt, prefix: shadow.vaultPathPrefix)
                return
            }
        }
    }

    private static func applyVaultPrefixIfEmpty(receipt: Receipt, prefix: String) {
        let existing = receipt.vaultPathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard existing.isEmpty, !prefix.isEmpty else { return }
        receipt.vaultPathPrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Promotes all shadow-linked receipts into an official `BusinessEntity` vault tree.
    @discardableResult
    static func mergeShadowProfile(
        _ shadow: PreliminaryBusinessEntity,
        into official: BusinessEntity,
        context: ModelContext
    ) throws -> Int {
        let prefix = ReceiptVaultPathing.sanitizePathSegment(official.legalName)
        var count = 0
        for receipt in shadow.linkedReceipts {
            receipt.preliminaryBusinessEntity = nil
            receipt.vaultPathPrefix = prefix
            if let payee = receipt.payeeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
               RegistryEntityPolarity.matchesEntityName(payee, in: [official.legalName])
            {
                let docType = DocumentTypeOption.fromStored(receipt.documentType)
                receipt.total = AccountingAmountPolarity.canonicalTotal(documentType: docType, amount: receipt.total)
            }
            count += 1
        }
        shadow.mergedIntoBusinessEntity = official
        shadow.updatedAt = .now
        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: auditKindShadowBulkMerge,
            title: "Shadow profile merged into corporate registry",
            detail: "shadow:\(shadow.id.uuidString);entity:\(official.id.uuidString);receipts:\(count)"
        )
        return count
    }

    static func countUnmergedShadowReceipts(matching legalName: String, context: ModelContext) -> Int {
        guard let shadow = matchingShadow(forLegalName: legalName, context: context) else { return 0 }
        return shadow.linkedReceipts.count
    }
}

// MARK: - Payor contact harvest

@MainActor
enum CheckContactHarvester {
    static func harvestPayorIfNeeded(
        payorName: String?,
        payorAddress: String?,
        receipt: Receipt,
        context: ModelContext
    ) {
        let name = payorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return }
        if receipt.counterpartyContact != nil { return }

        let fd = FetchDescriptor<ProductionContact>()
        let contacts = (try? context.fetch(fd)) ?? []
        if let existing = contacts.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
                || ($0.companyName?.caseInsensitiveCompare(name) == .orderedSame)
        }) {
            receipt.counterpartyContact = existing
            existing.updatedAt = .now
            if let addr = payorAddress?.nilIfEmpty, (existing.notes ?? "").isEmpty {
                existing.notes = "Address from check OCR:\n\(addr)"
            }
            return
        }

        let addr = payorAddress?.nilIfEmpty
        let contact = ProductionContact(
            name: name,
            companyName: name,
            tags: ["Check payor"],
            notes: addr.map { "Harvested from check OCR.\n\($0)" } ?? "Harvested from check OCR."
        )
        context.insert(contact)
        receipt.counterpartyContact = contact
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
