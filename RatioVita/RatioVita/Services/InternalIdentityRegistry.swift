import Foundation
import SwiftData

/// Keeps owned corporations and the principal owner out of the external vendor contact list.
@MainActor
enum InternalIdentityRegistry {
    private static let ownerNameDefaultsKey = "com.ratiovita.internalOwnerLegalName"
    private static let ownerVariancesDefaultsKey = "com.ratiovita.internalOwnerNameVariances"

    private static let payrollDisplayNameKey = "com.ratiovita.payrollDisplayName"

    static var ownerLegalName: String {
        get {
            UserDefaults.standard.string(forKey: ownerNameDefaultsKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: ownerNameDefaultsKey)
        }
    }

    /// Single canonical name for payroll PDF **NAME** lines (never OCR variance aliases).
    static var payrollDisplayName: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: payrollDisplayNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty
            {
                return stored
            }
            return canonicalName(from: ownerLegalName)
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: payrollDisplayNameKey)
        }
    }

    /// First name segment before comma — ignores alias lists accidentally pasted into legal name.
    static func canonicalName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let firstSegment = trimmed.split(separator: ",").first.map(String.init) ?? trimmed
        let parts = firstSegment
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count >= 2 else { return firstSegment }
        return "\(parts[0]) \(parts[parts.count - 1])"
    }

    static var ownerNameVariances: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: ownerVariancesDefaultsKey),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            let trimmed = newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: ownerVariancesDefaultsKey)
            }
        }
    }

    static func syncOwnedEntities(context: ModelContext) {
        let entities = (try? context.fetch(FetchDescriptor<BusinessEntity>())) ?? []
        let owned = entities.filter(\.isOwnedCorporation)
        let contacts = (try? context.fetch(FetchDescriptor<ProductionContact>())) ?? []

        for contact in contacts {
            if let entity = CorporateIdentityMatcher.matchesOwnedCorporation(
                contactName: contact.name,
                companyName: contact.companyName,
                ownedCorporations: owned
            ) {
                if contact.entityClassification != .ownedCorporateBody {
                    contact.entityClassification = .ownedCorporateBody
                    contact.updatedAt = .now
                }
                if contact.companyName == nil || contact.companyName?.isEmpty == true {
                    contact.companyName = entity.legalName
                }
                continue
            }

            if CorporateIdentityMatcher.matchesInternalOwner(
                contactName: contact.name,
                companyName: contact.companyName,
                ownerLegalName: ownerLegalName,
                nameVariances: ownerNameVariances
            ) {
                if contact.entityClassification != .internalOwner {
                    contact.entityClassification = .internalOwner
                    contact.updatedAt = .now
                }
            }
        }

        try? context.save()
    }

    static func classify(
        contact: ProductionContact,
        ownedCorporations: [BusinessEntity]
    ) -> ContactEntityClassification {
        if contact.entityClassification.isInternalIdentity {
            return contact.entityClassification
        }
        if CorporateIdentityMatcher.matchesOwnedCorporation(
            contactName: contact.name,
            companyName: contact.companyName,
            ownedCorporations: ownedCorporations
        ) != nil {
            return .ownedCorporateBody
        }
        if CorporateIdentityMatcher.matchesInternalOwner(
            contactName: contact.name,
            companyName: contact.companyName,
            ownerLegalName: ownerLegalName,
            nameVariances: ownerNameVariances
        ) {
            return .internalOwner
        }
        return .externalVendor
    }
}
