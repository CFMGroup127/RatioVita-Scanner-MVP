import Foundation

/// Default payroll paperwork for a show — crew timecards, talent sheets, or ACTRA vouchers.
enum ProductionPayrollDocumentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case epCrewWeekly
    case castCrewCanada
    case castTalentToronto
    case actraWhiteVoucher
    case actraGreenVoucher

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case crew
        case talent
        case actraVoucher
    }

    var group: Group {
        switch self {
            case .epCrewWeekly, .castCrewCanada: .crew
            case .castTalentToronto: .talent
            case .actraWhiteVoucher, .actraGreenVoucher: .actraVoucher
        }
    }

    var menuTitle: String {
        switch self {
            case .epCrewWeekly: "EP — Crew weekly timesheet"
            case .castCrewCanada: "Cast & Crew — Crew timecard (Canada)"
            case .castTalentToronto: "Cast & Crew — Talent timecard (Toronto)"
            case .actraWhiteVoucher: "ACTRA — White voucher"
            case .actraGreenVoucher: "ACTRA — Green voucher"
        }
    }

    /// Bundled PDF templates shipped in the app today.
    var isBundledTemplateAvailable: Bool {
        timecardFormat != nil
    }

    var timecardFormat: TimecardPDFFormatKind? {
        switch self {
            case .epCrewWeekly: .epCanadaCrewWeekly
            case .castCrewCanada: .castAndCrewCrewCanada
            case .castTalentToronto: .castAndCrewTalentToronto
            case .actraWhiteVoucher, .actraGreenVoucher: nil
        }
    }

    static func fromStored(_ raw: String?) -> ProductionPayrollDocumentKind {
        guard let raw, let match = ProductionPayrollDocumentKind(rawValue: raw) else {
            return .epCrewWeekly
        }
        return match
    }

    static var crewCases: [ProductionPayrollDocumentKind] {
        allCases.filter { $0.group == .crew }
    }

    static var talentCases: [ProductionPayrollDocumentKind] {
        allCases.filter { $0.group == .talent }
    }

    static var actraCases: [ProductionPayrollDocumentKind] {
        allCases.filter { $0.group == .actraVoucher }
    }
}
