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

        if routeViaProductionMode(
            receipt: receipt,
            merged: merged,
            ocr: ocr,
            owned: owned,
            context: context
        ) {
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

    // MARK: - Production → Ventures cross-reference

    /// Links Production Mode shows to their Ventures Hub corporate anchor (e.g. Reacher → Bespoke).
    private static func routeViaProductionMode(
        receipt: Receipt,
        merged: ExtractedData,
        ocr: String,
        owned: [BusinessEntity],
        context: ModelContext
    ) -> Bool {
        let client = payingClientName(merged: merged, receipt: receipt)

        if let project = receipt.productionProject ?? resolveProductionByHints(
            merged: merged,
            receipt: receipt,
            ocr: ocr,
            client: client,
            context: context
        ) {
            receipt.productionProject = project
            if linkProductionToVenturesAnchor(
                project: project,
                receipt: receipt,
                client: client,
                merged: merged,
                owned: owned,
                context: context
            ) {
                return true
            }
        }

        if let client,
           let project = findProductionByBillingClient(client, context: context)
        {
            receipt.productionProject = project
            if linkProductionToVenturesAnchor(
                project: project,
                receipt: receipt,
                client: client,
                merged: merged,
                owned: owned,
                context: context
            ) {
                return true
            }
        }

        return false
    }

    private static func linkProductionToVenturesAnchor(
        project: ProductionProject,
        receipt: Receipt,
        client: String?,
        merged: ExtractedData,
        owned: [BusinessEntity],
        context: ModelContext
    ) -> Bool {
        if let entity = project.businessEntity {
            anchorToCorporateHub(
                receipt: receipt,
                entity: entity,
                payingClient: client ?? project.billingClientCompanyName,
                productionProject: project,
                context: context
            )
            return true
        }

        if let entity = resolveCorporateForProduction(
            project: project,
            client: client,
            merged: merged,
            owned: owned,
            context: context
        ) {
            project.businessEntity = entity
            project.parentBusinessTitle = entity.legalName
            project.updatedAt = .now
            anchorToCorporateHub(
                receipt: receipt,
                entity: entity,
                payingClient: client ?? project.billingClientCompanyName,
                productionProject: project,
                context: context
            )
            return true
        }

        return false
    }

    private static func resolveCorporateForProduction(
        project: ProductionProject,
        client: String?,
        merged: ExtractedData,
        owned: [BusinessEntity],
        context: ModelContext
    ) -> BusinessEntity? {
        let hints = [
            client,
            project.billingClientCompanyName,
            project.payrollProductionCompany,
            project.parentBusinessTitle,
            merged.clientProductionCompany,
        ]
        for hint in hints.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            if let entity = CorporateIdentityMatcher.matchesOwnedCorporation(
                contactName: hint,
                companyName: nil,
                ownedCorporations: owned
            ) {
                return entity
            }
            if let entity = owned.first(where: {
                $0.legalName.localizedCaseInsensitiveCompare(hint) == .orderedSame
            }) {
                return entity
            }
        }

        if let siblingEntity = corporateEntityFromSiblingProductions(
            billingClient: client ?? project.billingClientCompanyName,
            excluding: project.id,
            context: context
        ) {
            return siblingEntity
        }

        return nil
    }

    private static func resolveProductionByHints(
        merged: ExtractedData,
        receipt: Receipt,
        ocr: String,
        client: String?,
        context: ModelContext
    ) -> ProductionProject? {
        let showHints = [
            receipt.invoiceClientProjectTitle,
            merged.clientProductionCompany,
            extractShowTitle(from: ocr),
        ]
        let projects = (try? context.fetch(FetchDescriptor<ProductionProject>())) ?? []
        for hint in showHints.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            if let match = projects.first(where: {
                $0.title.localizedCaseInsensitiveCompare(hint) == .orderedSame
            }) {
                return match
            }
            if let match = projects.first(where: {
                $0.title.localizedCaseInsensitiveContains(hint)
                    || hint.localizedCaseInsensitiveContains($0.title)
            }) {
                return match
            }
        }
        if let client {
            return findProductionByBillingClient(client, context: context)
        }
        return nil
    }

    private static func findProductionByBillingClient(_ client: String, context: ModelContext) -> ProductionProject? {
        let trimmed = client.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let projects = (try? context.fetch(FetchDescriptor<ProductionProject>())) ?? []
        return projects.first { project in
            let billing = project.billingClientCompanyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let payroll = project.payrollProductionCompany?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return billing.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
                || payroll.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
                || billing.localizedCaseInsensitiveContains(trimmed)
                || trimmed.localizedCaseInsensitiveContains(billing)
        }
    }

    private static func corporateEntityFromSiblingProductions(
        billingClient: String?,
        excluding projectID: UUID,
        context: ModelContext
    ) -> BusinessEntity? {
        let client = billingClient?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !client.isEmpty else { return nil }
        let projects = (try? context.fetch(FetchDescriptor<ProductionProject>())) ?? []
        for sibling in projects where sibling.id != projectID {
            guard let entity = sibling.businessEntity else { continue }
            let billing = sibling.billingClientCompanyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if billing.localizedCaseInsensitiveCompare(client) == .orderedSame
                || billing.localizedCaseInsensitiveContains(client)
                || client.localizedCaseInsensitiveContains(billing)
            {
                return entity
            }
        }
        return nil
    }

    private static func extractShowTitle(from ocr: String) -> String? {
        let patterns = [
            #"(?i)prod(?:uction)?\.?\s*title[:\s]+([^\n]{3,80})"#,
            #"(?i)show[:\s]+([^\n]{3,80})"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: ocr, range: NSRange(ocr.startIndex..., in: ocr)),
                  let range = Range(match.range(at: 1), in: ocr)
            else { continue }
            let title = String(ocr[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if title.count >= 3 { return title }
        }
        return nil
    }

    // MARK: - Hub assignment

    private static func anchorToCorporateHub(
        receipt: Receipt,
        entity: BusinessEntity,
        payingClient: String?,
        productionProject: ProductionProject? = nil,
        context: ModelContext
    ) {
        let project = productionProject ?? receipt.productionProject
        if receipt.productionProject == nil,
           let client = payingClient?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty
        {
            let linked = findOrCreateProduction(
                title: client,
                clientCompany: client,
                entity: entity,
                context: context
            )
            receipt.productionProject = linked
        } else if let project {
            project.businessEntity = entity
            project.parentBusinessTitle = entity.legalName
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
        let venturesLine = "Ventures parent: \(entity.legalName)"
        if receipt.notes?.contains(venturesLine) != true {
            receipt.notes = [receipt.notes, venturesLine].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
        if let client = payingClient?.trimmingCharacters(in: .whitespacesAndNewlines), !client.isEmpty {
            let clientLine = "Paying client: \(client)"
            if receipt.notes?.contains(clientLine) != true {
                receipt.notes = [receipt.notes, clientLine].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            }
        }
        if let show = (productionProject ?? receipt.productionProject)?.title {
            let showLine = "Production track: \(show)"
            if receipt.notes?.contains(showLine) != true {
                receipt.notes = [receipt.notes, showLine].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
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
            existing.parentBusinessTitle = entity.legalName
            existing.billingClientCompanyName = clientCompany
            existing.updatedAt = .now
            return existing
        }
        let project = ProductionProject(
            title: trimmed,
            notes: "Auto-linked from corporate anchor routing.",
            parentBusinessTitle: entity.legalName,
            billingClientCompanyName: clientCompany
        )
        project.businessEntity = entity
        context.insert(project)
        return project
    }
}
