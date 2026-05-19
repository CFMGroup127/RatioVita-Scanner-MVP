import Foundation

/// Labor / residency / naming rules for official EP & Cast & Crew PDF stamping.
struct PayrollComplianceProfile: Codable, Equatable {
    var residencyStatus: ResidencyTier?
    var guildStatus: GuildTier?
    var namingPreference: NamingMaskTier

    /// Two- or three-letter stamps for EP approval boxes (bottom right).
    var approvalInitialsProd: String
    var approvalInitialsPM: String
    var approvalInitialsAcct: String
    var approvalInitialsDept: String
    var approvalInitialsCrew: String
    /// When true, stamps crew initials on every EP export (unless production disables).
    var autoStampCrewInitials: Bool

    enum ResidencyTier: String, Codable, CaseIterable, Identifiable {
        case resident
        case nonResident

        var id: String { rawValue }

        var label: String {
            switch self {
                case .resident: "Resident"
                case .nonResident: "Non resident"
            }
        }
    }

    enum GuildTier: String, Codable, CaseIterable, Identifiable {
        case member
        case permit

        var id: String { rawValue }

        var label: String {
            switch self {
                case .member: "Member"
                case .permit: "Permit"
            }
        }
    }

    enum NamingMaskTier: String, Codable, CaseIterable, Identifiable {
        case personalOnly
        case corpOnly
        case both

        var id: String { rawValue }

        var label: String {
            switch self {
                case .personalOnly: "Personal name only"
                case .corpOnly: "Company name only"
                case .both: "Personal + company"
            }
        }
    }

    static let `default` = PayrollComplianceProfile(
        residencyStatus: nil,
        guildStatus: nil,
        namingPreference: .personalOnly,
        approvalInitialsProd: "",
        approvalInitialsPM: "",
        approvalInitialsAcct: "",
        approvalInitialsDept: "",
        approvalInitialsCrew: "",
        autoStampCrewInitials: false
    )
}

/// Persists payroll compliance choices (UserDefaults — no migration).
@MainActor
enum PayrollComplianceProfileStore {
    private static let storageKey = "com.ratiovita.payrollComplianceProfile"
    private static let namingKey = "com.ratiovita.payrollNamingMask"

    static var profile: PayrollComplianceProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode(PayrollComplianceProfile.self, from: data) else
            {
                var base = PayrollComplianceProfile.default
                if let raw = UserDefaults.standard.string(forKey: namingKey),
                   let tier = PayrollComplianceProfile.NamingMaskTier(rawValue: raw)
                {
                    base.namingPreference = tier
                }
                return base
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            UserDefaults.standard.set(newValue.namingPreference.rawValue, forKey: namingKey)
        }
    }

    static var namingPreference: PayrollComplianceProfile.NamingMaskTier {
        get { profile.namingPreference }
        set {
            var p = profile
            p.namingPreference = newValue
            profile = p
        }
    }

    static var userInitials: String {
        get {
            UserDefaults.standard.string(forKey: "com.ratiovita.payrollUserInitials")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                forKey: "com.ratiovita.payrollUserInitials"
            )
        }
    }

    static var autoStampCrewInitials: Bool {
        get { profile.autoStampCrewInitials }
        set {
            var p = profile
            p.autoStampCrewInitials = newValue
            profile = p
        }
    }

    static func suggestedInitials(from legalName: String) -> String {
        let parts = legalName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        guard !parts.isEmpty else { return "" }
        if parts.count == 1 { return String(parts[0].prefix(3)).uppercased() }
        let first = parts[0].prefix(1)
        let last = parts[parts.count - 1].prefix(1)
        return "\(first)\(last)".uppercased()
    }
}
