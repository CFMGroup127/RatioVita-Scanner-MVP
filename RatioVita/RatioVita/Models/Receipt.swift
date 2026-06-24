import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var merchant: String
    var total: Decimal
    var currencyCode: String
    var notes: String?

    /// Parsed transaction date from the document when available (distinct from `createdAt` ingest time).
    var transactionDate: Date?
    var vendorAddress: String?
    var documentNumber: String?
    /// Physical cheque / bank clearing number (distinct from vendor invoice #).
    var chequeNumber: String?
    /// Your issued invoice # on a remittance stub (e.g. Bespoke invoice 8011).
    var internalInvoiceNumber: String?
    /// Client / network accounting token (SAP document #, ref. document).
    var clientAccountingToken: String?
    /// AR/AP: external reference invoice # for document graph (anchors payment ↔ invoice).
    var referenceInvoiceNumber: String?
    var paymentMethodSummary: String?
    var subtotalAmount: Decimal?
    var taxAmount: Decimal?
    /// `gemini`, `heuristic`, or `manual` after user edits.
    var extractionSource: String
    var documentKind: String?
    /// User-selected document classification (Receipt/Invoice/Paycheck/etc.) used for filing and linking.
    var documentType: String
    /// Freeform OCR or user notes about handwriting (e.g. “edep oct 14/19”).
    var annotations: String?
    /// Deposit date inferred from handwritten “edep …” (if present) or entered manually.
    var depositDate: Date?
    /// User has verified totals, dates, and line items in the Review UI.
    var isVerified: Bool = false
    /// Reserved for matching to a bank / ledger transaction (document graph **Linked**).
    var isLedgerLinked: Bool = false
    /// Tax / bookkeeping category (Tax Agent suggestions; user may edit before verify).
    var taxCategory: String?
    /// After filing from Review, suggested cabinet (`DocumentCabinet.rawValue`) for Vehicles / Equipment / Tools.
    var filingCabinetKindRaw: String?
    /// Optional Arctic path **prefix** before merchant/year/month (e.g. `Productions/Bell Media`). Nil = root library.
    var vaultPathPrefix: String?
    /// High-level production classification (e.g. commercial, series, payroll stub).
    var productionType: String?
    /// Canonical show / series; preferred over loose strings on `WorkSession`.
    var productionProject: ProductionProject?
    /// Department or crew role summary for the document (e.g. Craft Services, Costumes).
    var department: String?
    /// CapEx / culinary / media tier for high-volume production hubs (New Horizons).
    var expenseClassificationRaw: String?
    /// Physical zone at 176 Yonge (e.g. Floor 2 Terrace, Rooftop Canopy).
    var physicalZoneTag: String?

    /// 0…100 suggested or user-edited business-use allocation for tax prep (nil = unset).
    var businessUsePercent: Double?
    /// Agent-suggested business-use % (e.g. time sheet anchor) shown as a hint while the user edits
    /// `businessUsePercent`.
    var businessUseSuggestedPercent: Double?
    /// When true, `businessUsePercent` was set from a `WorkRecord` calendar match (time sheet anchor).
    var businessUseVerifiedByTimeSheet: Bool = false

    /// When true, this receipt is shown only in the Review tab until the user files it.
    var pendingHumanReview: Bool = false
    /// True if any page came from the device camera (eligible for Photos mirror after filing).
    var scannedViaCamera: Bool = false
    /// User marks “reviewed” before tapping File & save in the Review tab.
    var reviewChecklistDone: Bool = false
    /// User chose **Decouple & File Later** on deal-memo timecard onboarding (banner hidden until reset).
    var dealMemoTimecardPromptDismissed: Bool = false
    /// Multi-page batch stays in Review until the user files or clears the pin (survives extract/decouple commits).
    var workspaceBatchPinned: Bool = false
    /// When this row was split from a parent batch, points at the original multi-page receipt id.
    var parentBatchReceiptID: UUID?
    /// Crew invoice you issued on someone else's behalf (segregated from personal/corporate books).
    var facilitatedThirdPartyLabor: Bool = false
    /// Cross-entity triage: mixed personal / venture / production routing required.
    var requiresCrossEntityTriage: Bool = false
    /// Secure inbox registry UUID that discovered this document.
    var sourceSecureInboxID: String?
    var sourceSecureInboxEmail: String?
    /// Set when every line item (or whole receipt) has been routed to a hub.
    var crossEntityTriagedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptImage.receipt) var images: [ReceiptImage]
    @Relationship(deleteRule: .cascade, inverse: \ReceiptLineItem.receipt) var lineItems: [ReceiptLineItem]
    /// When the receipt is removed, keep `WorkSession` rows but clear `receipt` so time-report data is not silently
    /// cascade-deleted.
    @Relationship(deleteRule: .nullify, inverse: \WorkSession.receipt) var workSessions: [WorkSession]
    /// Extracted time-sheet / pay-stub day rows (Sprint E forensic layer).
    @Relationship(deleteRule: .cascade, inverse: \WorkRecord.sourceReceipt) var workRecords: [WorkRecord]
    /// Outgoing graph edges (`fromReceipt` = self). Nullify clears `fromReceipt` on the link when this receipt is
    /// deleted (link row may remain with nil `fromReceipt`; peer `toReceipt` is unchanged).
    @Relationship(
        deleteRule: .nullify,
        inverse: \ReceiptReferenceLink.fromReceipt
    ) var referenceLinks: [ReceiptReferenceLink]
    /// Reference rows where this receipt is the **target** (`toReceipt`) of a link.
    @Relationship(deleteRule: .nullify, inverse: \ReceiptReferenceLink.toReceipt)
    var incomingReferenceLinks: [ReceiptReferenceLink]
    /// Primary bank row linked to this receipt. Persisted inverse of `BankTransaction.matchedReceipt` (macro only on
    /// `BankTransaction` to avoid circular `@Relationship` expansion).
    var matchedBankTransaction: BankTransaction?
    /// Deposit slip / statement mapped to a ledger account (including closed historical accounts).
    var ledgerBankAccount: LedgerBankAccount?
    /// CRM / Zoho: client or payer linked to this document (`@Relationship` macro lives on `ProductionContact`).
    var counterpartyContact: ProductionContact?
    /// “Pay to the order of …” on checks (your corporate entity when receiving funds).
    var payeeName: String?
    /// Drawer / payer on incoming checks.
    var payorName: String?
    /// Shadow Corporate Registry profile (pre–Articles of Incorporation).
    var preliminaryBusinessEntity: PreliminaryBusinessEntity?
    /// Catering / production invoices: PO # when extracted.
    var invoicePurchaseOrderNumber: String?
    /// Production manager or billing contact name from invoice.
    var invoiceProductionManagerName: String?
    /// Client project / episode title (e.g. "Section 2", "Drive Spoiler Free").
    var invoiceClientProjectTitle: String?
    /// Production company or network on invoice ("Bell Media Inc.").
    var invoiceClientCompany: String?
    /// When filed from Review **Convert to Asset**.
    var sourceEquipmentAsset: EquipmentAsset?

    // MARK: - Computed Properties

    /// Cached first image for performance in list views
    var firstImage: RVImage? {
        images.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.platformImage
    }

    /// Used for Finder-style **Column** view and “Project title” sorting.
    var libraryColumnGroupTitle: String {
        if let t = productionProject?.title.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        let sortedSessions = workSessions.sorted { $0.sortIndex < $1.sortIndex }
        if let t = sortedSessions.first?.productionProject?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           !t.isEmpty
        {
            return t
        }
        if let title = sortedSessions.first?.productionTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty
        {
            return title
        }
        if let pt = productionType?.trimmingCharacters(in: .whitespacesAndNewlines), !pt.isEmpty {
            return pt
        }
        return "General"
    }

    /// When set, the receipt lives in Trash and can be recovered or permanently deleted.
    var trashedAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        merchant: String,
        total: Decimal,
        currencyCode: String = ReceiptCurrency.defaultForLocale.code,
        notes: String? = nil,
        transactionDate: Date? = nil,
        vendorAddress: String? = nil,
        documentNumber: String? = nil,
        chequeNumber: String? = nil,
        internalInvoiceNumber: String? = nil,
        clientAccountingToken: String? = nil,
        referenceInvoiceNumber: String? = nil,
        paymentMethodSummary: String? = nil,
        subtotalAmount: Decimal? = nil,
        taxAmount: Decimal? = nil,
        extractionSource: String = "heuristic",
        documentKind: String? = nil,
        documentType: String = DocumentTypeOption.receipt.rawValue,
        annotations: String? = nil,
        depositDate: Date? = nil,
        isVerified: Bool = false,
        isLedgerLinked: Bool = false,
        taxCategory: String? = nil,
        filingCabinetKindRaw: String? = nil,
        vaultPathPrefix: String? = nil,
        productionType: String? = nil,
        productionProject: ProductionProject? = nil,
        department: String? = nil,
        expenseClassificationRaw: String? = nil,
        physicalZoneTag: String? = nil,
        businessUsePercent: Double? = nil,
        businessUseSuggestedPercent: Double? = nil,
        businessUseVerifiedByTimeSheet: Bool = false,
        images: [ReceiptImage] = [],
        lineItems: [ReceiptLineItem] = [],
        workSessions: [WorkSession] = [],
        workRecords: [WorkRecord] = [],
        referenceLinks: [ReceiptReferenceLink] = [],
        incomingReferenceLinks: [ReceiptReferenceLink] = [],
        matchedBankTransaction: BankTransaction? = nil,
        ledgerBankAccount: LedgerBankAccount? = nil,
        counterpartyContact: ProductionContact? = nil,
        payeeName: String? = nil,
        payorName: String? = nil,
        preliminaryBusinessEntity: PreliminaryBusinessEntity? = nil,
        invoicePurchaseOrderNumber: String? = nil,
        invoiceProductionManagerName: String? = nil,
        invoiceClientProjectTitle: String? = nil,
        invoiceClientCompany: String? = nil,
        sourceEquipmentAsset: EquipmentAsset? = nil,
        pendingHumanReview: Bool = false,
        scannedViaCamera: Bool = false,
        reviewChecklistDone: Bool = false,
        dealMemoTimecardPromptDismissed: Bool = false,
        workspaceBatchPinned: Bool = false,
        parentBatchReceiptID: UUID? = nil,
        facilitatedThirdPartyLabor: Bool = false,
        requiresCrossEntityTriage: Bool = false,
        sourceSecureInboxID: String? = nil,
        sourceSecureInboxEmail: String? = nil,
        crossEntityTriagedAt: Date? = nil,
        trashedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.merchant = merchant
        self.total = total
        self.currencyCode = currencyCode
        self.notes = notes
        self.transactionDate = transactionDate
        self.vendorAddress = vendorAddress
        self.documentNumber = documentNumber
        self.chequeNumber = chequeNumber
        self.internalInvoiceNumber = internalInvoiceNumber
        self.clientAccountingToken = clientAccountingToken
        self.referenceInvoiceNumber = referenceInvoiceNumber
        self.paymentMethodSummary = paymentMethodSummary
        self.subtotalAmount = subtotalAmount
        self.taxAmount = taxAmount
        self.extractionSource = extractionSource
        self.documentKind = documentKind
        self.documentType = documentType
        self.annotations = annotations
        self.depositDate = depositDate
        self.isVerified = isVerified
        self.isLedgerLinked = isLedgerLinked
        self.taxCategory = taxCategory
        self.filingCabinetKindRaw = filingCabinetKindRaw
        self.vaultPathPrefix = vaultPathPrefix
        self.productionType = productionType
        self.productionProject = productionProject
        self.department = department
        self.expenseClassificationRaw = expenseClassificationRaw
        self.physicalZoneTag = physicalZoneTag
        self.businessUsePercent = businessUsePercent
        self.businessUseSuggestedPercent = businessUseSuggestedPercent
        self.businessUseVerifiedByTimeSheet = businessUseVerifiedByTimeSheet
        self.images = images
        self.lineItems = lineItems
        self.workSessions = workSessions
        self.workRecords = workRecords
        self.referenceLinks = referenceLinks
        self.incomingReferenceLinks = incomingReferenceLinks
        self.matchedBankTransaction = matchedBankTransaction
        self.ledgerBankAccount = ledgerBankAccount
        self.counterpartyContact = counterpartyContact
        self.payeeName = payeeName
        self.payorName = payorName
        self.preliminaryBusinessEntity = preliminaryBusinessEntity
        self.invoicePurchaseOrderNumber = invoicePurchaseOrderNumber
        self.invoiceProductionManagerName = invoiceProductionManagerName
        self.invoiceClientProjectTitle = invoiceClientProjectTitle
        self.invoiceClientCompany = invoiceClientCompany
        self.sourceEquipmentAsset = sourceEquipmentAsset
        self.pendingHumanReview = pendingHumanReview
        self.scannedViaCamera = scannedViaCamera
        self.reviewChecklistDone = reviewChecklistDone
        self.dealMemoTimecardPromptDismissed = dealMemoTimecardPromptDismissed
        self.workspaceBatchPinned = workspaceBatchPinned
        self.parentBatchReceiptID = parentBatchReceiptID
        self.facilitatedThirdPartyLabor = facilitatedThirdPartyLabor
        self.requiresCrossEntityTriage = requiresCrossEntityTriage
        self.sourceSecureInboxID = sourceSecureInboxID
        self.sourceSecureInboxEmail = sourceSecureInboxEmail
        self.crossEntityTriagedAt = crossEntityTriagedAt
        self.trashedAt = trashedAt
    }

    /// Merges persisted structured fields with a fresh OCR heuristic parse (for legacy rows and gaps).
    @MainActor
    func displayExtractedData(fallbackFromOCR parsed: ExtractedData) -> ExtractedData {
        let fromPersistedLines: [LineItem]? = {
            let sorted = lineItems.sorted { $0.sortIndex < $1.sortIndex }
            guard !sorted.isEmpty else { return nil }
            return sorted.map {
                LineItem(
                    description: $0.lineDescription,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice,
                    totalPrice: $0.totalPrice,
                    serialNumber: $0.serialNumber,
                    confidence: nil
                )
            }
        }()

        let mergedLines: [LineItem]? = if let fromPersistedLines, !fromPersistedLines.isEmpty {
            fromPersistedLines
        } else {
            parsed.lineItems
        }

        let merchantField: String = {
            let m = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            if m.lowercased() == "unknown merchant" {
                return parsed.merchant ?? m
            }
            return m.isEmpty ? (parsed.merchant ?? "Unknown Merchant") : m
        }()

        return ExtractedData(
            merchant: merchantField,
            payee: payeeName,
            payor: payorName,
            payorAddress: nil,
            total: total,
            currency: currencyCode,
            date: transactionDate ?? parsed.date,
            vendorAddress: vendorAddress ?? parsed.vendorAddress,
            documentNumber: documentNumber ?? parsed.documentNumber,
            purchaseOrderNumber: invoicePurchaseOrderNumber ?? parsed.purchaseOrderNumber,
            productionManagerName: invoiceProductionManagerName ?? parsed.productionManagerName,
            clientProjectTitle: invoiceClientProjectTitle ?? parsed.clientProjectTitle,
            clientProductionCompany: invoiceClientCompany ?? parsed.clientProductionCompany,
            paymentMethodSummary: paymentMethodSummary ?? parsed.paymentMethodSummary,
            lineItems: mergedLines,
            taxAmount: taxAmount ?? parsed.taxAmount,
            subtotal: subtotalAmount ?? parsed.subtotal,
            merchantConfidence: parsed.merchantConfidence,
            totalConfidence: parsed.totalConfidence,
            dateConfidence: parsed.dateConfidence,
            documentKind: documentKind ?? parsed.documentKind,
            workTimeEntries: parsed.workTimeEntries,
            chequeNumber: chequeNumber ?? parsed.chequeNumber,
            internalInvoiceNumber: internalInvoiceNumber ?? parsed.internalInvoiceNumber,
            clientAccountingToken: clientAccountingToken ?? parsed.clientAccountingToken
        )
    }
}
