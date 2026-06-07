import Foundation
import SwiftData

/// Sovereignty identity graph — legal name, aliases, family isolation, corporate links.
@Model
final class MasterUserIdentity {
    @Attribute(.unique) var id: UUID
    var primaryLegalName: String
    var addressCard: String
    /// Comma-separated phone numbers.
    var phoneNumbersRaw: String
    /// Comma-separated recognized aliases (payroll / invoice name variants).
    var recognizedNameAliasesRaw: String
    /// Spouse, children, dependents — payments in these names stay out of user gross ledgers.
    var isolatedFamilyNamesRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        primaryLegalName: String,
        addressCard: String = "",
        phoneNumbers: [String] = [],
        recognizedNameAliases: [String] = [],
        isolatedFamilyNames: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.primaryLegalName = primaryLegalName
        self.addressCard = addressCard
        phoneNumbersRaw = Self.encodeList(phoneNumbers)
        recognizedNameAliasesRaw = Self.encodeList(recognizedNameAliases)
        isolatedFamilyNamesRaw = Self.encodeList(isolatedFamilyNames)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func encodeList(_ items: [String]) -> String {
        items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "||")
    }

    static func decodeList(_ raw: String) -> [String] {
        raw.split(separator: "||", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension MasterUserIdentity {
    var phoneNumbers: [String] {
        get { Self.decodeList(phoneNumbersRaw) }
        set { phoneNumbersRaw = Self.encodeList(newValue) }
    }

    var recognizedNameAliases: [String] {
        get { Self.decodeList(recognizedNameAliasesRaw) }
        set { recognizedNameAliasesRaw = Self.encodeList(newValue) }
    }

    var isolatedFamilyNames: [String] {
        get { Self.decodeList(isolatedFamilyNamesRaw) }
        set { isolatedFamilyNamesRaw = Self.encodeList(newValue) }
    }

    /// All strings that should resolve to this user (not family-isolated).
    var resolutionNameSet: Set<String> {
        var set = Set<String>()
        let primary = primaryLegalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { set.insert(primary.lowercased()) }
        for alias in recognizedNameAliases {
            let t = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { set.insert(t.lowercased()) }
        }
        return set
    }

    var isolatedFamilyNameSet: Set<String> {
        Set(
            isolatedFamilyNames
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
}
