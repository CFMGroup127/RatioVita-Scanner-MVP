import Foundation
import SwiftData

/// Three-tier routing: corporate anchor hub, production client box, or personal employee ledger.
@MainActor
enum CorporateAnchorRoutingEngine {
    static func apply(
        receipt: Receipt,
        combinedOCR: String,
        merged: ExtractedData,
        context: ModelContext
    ) {
        let owned = ownedCorporations(context: context)
        guard !owned.isEmpty else { return }

        let ocr = combinedOCR
        let docType = DocumentTypeOption.fromStored(receipt.documentType)

        if let entity = resolveCorporateAnchor(
            ocr: ocr,
            merged: merged,
            receipt: receipt,
            owned: owned,
            context: context
        ) {
            anchorToCorporateHub(
                receipt: receipt,
                entity: entity,
                payingClient: payingClientName(merged: merged, receipt: receipt),
                context: context
            )
            return
        }

        if docType == .dealMemo || docType == .timeSheet || docType == .paycheck,
           isEmployeePersonalTrack(merged: merged, ocr: ocr)
        {
            routeToPersonalLedger(receipt: receipt)
            return
        }

        if let client = payingClientName(merged: merged, receipt: receipt),
           let entity = CorporateIdentityMatcher.matchesOwnedCorporation(
               contactName: merged.payee ?? receipt.payeeName ?? "",
               companyName: merged.merchant ?? receipt.merchant,
               ownedCorporations: owned
           )
        {
            anchorToCorporateHub(
                receipt: receipt,
                entity: entity,
                payingClient: client,
                context: context
            )
        }
    }

    // MARK: - Corporate match

    private static func resolveCorporateAnchor(
        ocr: String,
        merged: ExtractedData,
        receipt: Receipt,
        owned: [BusinessEntity],
        context: ModelContext
    ) -> BusinessEntity? {
        if let entity = TaxRegistrationAnchor.matchOwnedEntity(in: ocr, context: context) {
            return entity
        }
        let payee = merged.payee ?? receipt.payeeName ?? ""
        let merchant = merged.merchant ?? receipt.merchant
        if let entity = CorporateIdentityMatcher.matchesOwnedCorporation(
            contactName: payee,
            companyName: merchant,
            ownedCorporations: owned
        ) {
            return entity
        }
        return matchesFSOEndorsement(ocr: ocr, owned: owned)
    }

    private static func matchesFSOEndorsement(ocr: String, owned: [BusinessEntity]) -> BusinessEntity? {
        let lower = ocr.lowercased()
        guard lower.contains("fso") || lower.contains("for deposit only") else { return nil }
        for entity in owned where entity.isOwnedCorporation {
            let keywords = entity.legalName
                .lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 5 }
            if keywords.contains(where: { lower.contains($0) }) {
                return entity
            }
        }
        return nil
    }

    // MARK: - Hub assignment

    private static func anchorToCorporateHub(
        receipt: Receipt,
        entity: BusinessEntity,
        payingClient: String?,
        context: ModelContext
    ) {
        if receipt.productionProject == nil,
           let client = payingClient?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty
        {
            let project = findOrCreateProduction(
                title: client,
                clientCompany: client,
                entity: entity,
                context: context
            )
            receipt.productionProject = project
        } else if let project = receipt.productionProject {
            project.businessEntity = entity
            project.updatedAt = .now
            if let client = payingClient?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty {
                project.billingClientCompanyName = client
            }
        }

        receipt.preliminaryBusinessEntity = nil
        let vaultSegment = ReceiptVaultPathing.sanitizePathSegment(entity.legalName)
        if (receipt.vaultPathPrefix ?? "").isEmpty {
            receipt.vaultPathPrefix = vaultSegment
        }

        let anchorLine = "Corporate hub: \(entity.legalName)"
        if receipt.notes?.contains(anchorLine) != true {
            receipt.notes = [receipt.notes, anchorLine].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
        if let client = payingClient?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty {
            let clientLine = "Paying client: \(client)"
            if receipt.notes?.contains(clientLine) != true {
                receipt.notes = [receipt.notes, clientLine].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            }
        }
    }

    private static func routeToPersonalLedger(receipt: Receipt) {
        receipt.productionProject = nil
        receipt.preliminaryBusinessEntity = nil
        let line = "Personal employee ledger (long-format)."
        if receipt.notes?.contains(line) != true {
            receipt.notes = [receipt.notes, line].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    // MARK: - Helpers

    private static func ownedCorporations(context: ModelContext) -> [BusinessEntity] {
        (try? context.fetch(FetchDescriptor<BusinessEntity>()))?.filter(\.isOwnedCorporation) ?? []
    }

    private static func payingClientName(merged: ExtractedData, receipt: Receipt) -> String? {
        merged.clientProductionCompany
            ?? merged.payor
            ?? receipt.invoiceClientCompany
            ?? receipt.payorName
    }

    private static func isEmployeePersonalTrack(merged: ExtractedData, ocr: String) -> Bool {
        CorporateIdentityMatcher.matchesInternalOwner(
            contactName: merged.payee ?? merged.merchant ?? "",
            companyName: nil,
            ownerLegalName: InternalIdentityRegistry.ownerLegalName,
            nameVariances: InternalIdentityRegistry.ownerNameVariances
        )
        || CorporateIdentityMatcher.matchesInternalOwner(
            contactName: ocr,
            companyName: nil,
            ownerLegalName: InternalIdentityRegistry.ownerLegalName,
            nameVariances: InternalIdentityRegistry.ownerNameVariances
        )
    }

    private static func findOrCreateProduction(
        title: String,
        clientCompany: String,
        entity: BusinessEntity,
        context: ModelContext
    ) -> ProductionProject {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = (try? context.fetch(FetchDescriptor<ProductionProject>()))?
            .first { $0.title.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        if let existing {
            existing.businessEntity = entity
            existing.billingClientCompanyName = clientCompany
            existing.updatedAt = .now
            return existing
        }
        let project = ProductionProject(
            title: trimmed,
            notes: "Auto-linked from corporate anchor routing.",
            billingClientCompanyName: clientCompany
        )
        project.businessEntity = entity
        context.insert(project)
        return project
    }
}
