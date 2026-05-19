import Foundation
import SwiftData

/// Exports crew timecards using **official bundled PDF underlays** + native AcroForm field fill.
enum TimecardPDFFormatKind: String, CaseIterable, Identifiable {
    case epCanadaCrewWeekly = "EP Canada — Crew Weekly Timesheet"
    case castAndCrewCrewCanada = "Cast & Crew — Crew Timecard (Canada)"
    case castAndCrewTalentToronto = "Cast & Crew — Talent Timecard (Toronto)"

    var id: String { rawValue }

    var officialTemplate: TimecardOfficialTemplate {
        switch self {
            case .epCanadaCrewWeekly: .epCanadaCrewWeekly
            case .castAndCrewCrewCanada: .castAndCrewCrewCanada
            case .castAndCrewTalentToronto: .castAndCrewTalentToronto
        }
    }
}

enum TimecardDigitalTwinPDFGenerators {
    enum TwinError: Error {
        case couldNotCreatePDF
    }

    static func writeTwinPDF(
        kind: TimecardPDFFormatKind,
        productionTitle: String,
        occupation: String?,
        days: [CrewTimecardDay],
        workRecords: [WorkRecord],
        agreement: LaborAgreement,
        estimateByDayID: [UUID: SentinelPayEstimate],
        production: ProductionProject?
    ) throws -> URL {
        do {
            return try TimecardOfficialPDFComposer.writeFilledTimecard(
                template: kind.officialTemplate,
                productionTitle: productionTitle,
                occupation: occupation,
                days: days,
                workRecords: workRecords,
                agreement: agreement,
                estimateByDayID: estimateByDayID,
                production: production
            )
        } catch {
            throw TwinError.couldNotCreatePDF
        }
    }
}
