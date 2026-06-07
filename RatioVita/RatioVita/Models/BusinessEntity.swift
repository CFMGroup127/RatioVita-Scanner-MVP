import Foundation
import SwiftData

/// **Corporate registry** profile — legal entity behind productions and contractor invoices.
@Model
final class BusinessEntity {
    @Attribute(.unique) var id: UUID
    var legalName: String
    var gstHstNumber: String?
    /// CRA 9-digit Business Number core (e.g. `76001212`) — global identity anchor for OCR routing.
    var taxRegistrationNumber: String?
    var businessAddress: String?
    /// PNG/JPEG bytes for letterhead (optional).
    var logoImageData: Data?

    // MARK: - Articles (interim; see Docs/CREDENTIALS_COMPLIANCE_VAULT_BACKLOG.md)

    /// Full Articles of Incorporation package (PDF preferred).
    var articlesFullDocumentData: Data?
    /// Page 1 only — what productions / EP portal usually need on file.
    var articlesPageOneDocumentData: Data?
    var articlesDocumentFilename: String?
    var notes: String?
    /// `PaymentTermsMode.rawValue` — default payroll / AR cadence for productions that inherit from this entity.
    /// Inline default lets SwiftData populate legacy rows during lightweight migration.
    var paymentTermsRaw: String = ""
    /// When true, this is **your** corporation (AR polarity, excluded from external Contacts).
    /// Inline default is required so older on-disk stores migrate instead of failing (Code 134110).
    var isOwnedCorporation: Bool = false
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ProductionProject.businessEntity)
    var productionProjects: [ProductionProject]

    @Relationship(deleteRule: .nullify, inverse: \PreliminaryBusinessEntity.mergedIntoBusinessEntity)
    var mergedShadowProfiles: [PreliminaryBusinessEntity]

    @Relationship(deleteRule: .nullify, inverse: \EquipmentAsset.businessEntity)
    var equipmentAssets: [EquipmentAsset]

    init(
        id: UUID = UUID(),
        legalName: String,
        gstHstNumber: String? = nil,
        taxRegistrationNumber: String? = nil,
        businessAddress: String? = nil,
        logoImageData: Data? = nil,
        articlesFullDocumentData: Data? = nil,
        articlesPageOneDocumentData: Data? = nil,
        articlesDocumentFilename: String? = nil,
        notes: String? = nil,
        paymentTermsRaw: String = "",
        isOwnedCorporation: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        productionProjects: [ProductionProject] = [],
        mergedShadowProfiles: [PreliminaryBusinessEntity] = [],
        equipmentAssets: [EquipmentAsset] = []
    ) {
        self.id = id
        self.legalName = legalName
        self.gstHstNumber = gstHstNumber
        self.taxRegistrationNumber = taxRegistrationNumber
        self.businessAddress = businessAddress
        self.logoImageData = logoImageData
        self.articlesFullDocumentData = articlesFullDocumentData
        self.articlesPageOneDocumentData = articlesPageOneDocumentData
        self.articlesDocumentFilename = articlesDocumentFilename
        self.notes = notes
        self.paymentTermsRaw = paymentTermsRaw
        self.isOwnedCorporation = isOwnedCorporation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productionProjects = productionProjects
        self.mergedShadowProfiles = mergedShadowProfiles
        self.equipmentAssets = equipmentAssets
    }
}

extension BusinessEntity {
    var paymentTerms: PaymentTermsMode {
        get { PaymentTermsMode(rawValue: paymentTermsRaw) ?? .unspecified }
        set {
            paymentTermsRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var displaySubtitle: String {
        let bn = normalizedTaxRegistrationCore ?? ""
        if !bn.isEmpty { return "BN \(bn)" }
        let gst = gstHstNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if gst.isEmpty { return businessAddress ?? "" }
        return "GST/HST \(gst)"
    }

    var normalizedTaxRegistrationCore: String? {
        TaxRegistrationAnchor.normalizedBusinessNumber(from: taxRegistrationNumber)
            ?? TaxRegistrationAnchor.normalizedBusinessNumber(from: gstHstNumber)
    }
}
