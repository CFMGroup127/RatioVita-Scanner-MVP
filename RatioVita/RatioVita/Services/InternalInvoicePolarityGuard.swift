import Foundation
import SwiftData

/// When an incoming check’s internal invoice # matches a known AR invoice, hard-lock income polarity.
@MainActor
enum InternalInvoicePolarityGuard {
    static func applyIfNeeded(receipt: Receipt, context: ModelContext) {
        guard let token = receipt.internalInvoiceNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }

        let ownedNames = (try? context.fetch(FetchDescriptor<BusinessEntity>()))?
            .filter(\.isOwnedCorporation)
            .map(\.legalName) ?? []

        let payeeHit = RegistryEntityPolarity.matchesRegistryEntity(
            merchant: receipt.payeeName,
            payee: receipt.payeeName,
            supplementalOCR: nil,
            entityLegalNames: ownedNames
        )
        guard payeeHit else { return }

        receipt.documentType = DocumentTypeOption.incomeOrCheck.rawValue
        receipt.documentKind = "income"
        if receipt.referenceInvoiceNumber == nil || receipt.referenceInvoiceNumber?.isEmpty == true {
            receipt.referenceInvoiceNumber = token
        }

        FilingCoordinator.appendAudit(
            context: context,
            kindRaw: FilingCoordinator.auditKindInternalInvoicePolarityLock,
            title: "AR polarity lock (internal invoice #)",
            detail: "Invoice #\(token) on payee-owned cheque → income (+)"
        )
    }
}
