import Foundation
import SwiftData

/// Strips PII from sandbox views; accounting sees hash tokens only.
enum ConsultantTokenFactory {
    static func generateToken(for department: IndustryDepartmentScope) -> String {
        let suffix = String(UUID().uuidString.prefix(6)).uppercased()
        let prefix = department.rawValue.split(separator: "_").first.map(String.init) ?? "RV"
        return "H4SH-\(prefix)-\(suffix)"
    }

    static func generateInviteToken() -> String {
        "INV-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))"
    }
}

@MainActor
enum AnonymizedPayrollEngine {
    static func generateToken(for department: IndustryDepartmentScope) -> String {
        ConsultantTokenFactory.generateToken(for: department)
    }

    static func maskDisplayName(_ legalName: String) -> String {
        let trimmed = legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "ANON" }
        return generateToken(for: .transport)
    }

    static var estimatedGrossDisclaimer: String {
        """
        Calculations reflect estimated gross earnings based on active union hourly tiers. \
        Final net distributions vary by CRA brackets, CPP, EI, union dues, and fringe benefits.
        """
    }

    static func estimatedGross(hours: Double, hourlyRate: Double, kitAllowance: Double) -> Decimal {
        let base = Decimal(hours) * Decimal(hourlyRate)
        return base + Decimal(kitAllowance)
    }
}
