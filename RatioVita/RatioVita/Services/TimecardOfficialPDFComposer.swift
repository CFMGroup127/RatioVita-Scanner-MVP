import CoreGraphics
import Foundation
import SwiftData

#if canImport(PDFKit)
import PDFKit
#endif

/// Official blank payroll PDFs bundled under `Resources/PayrollTemplates/` (100% visual underlay).
enum TimecardOfficialTemplate: String, CaseIterable, Identifiable {
    case epCanadaCrewWeekly = "EP Canada — Crew Weekly Timesheet"
    case castAndCrewCrewCanada = "Cast & Crew — Crew Timecard (Canada)"
    case castAndCrewTalentToronto = "Cast & Crew — Talent Timecard (Toronto)"

    var id: String { rawValue }

    /// Bundle resource name (without `.pdf`).
    var bundleResourceName: String {
        switch self {
            case .epCanadaCrewWeekly: "EP_Crew_Weekly_Timesheet"
            case .castAndCrewCrewCanada: "CastAndCrew_Crew_Timecard_Canada"
            case .castAndCrewTalentToronto: "CastAndCrew_Talent_Timecard_Toronto"
        }
    }
}

/// Fills official payroll PDFs using native AcroForm fields when available (exact box alignment).
enum TimecardOfficialPDFComposer {
    enum ComposeError: Error {
        case templateMissing(String)
        case couldNotCreatePDF
    }

    static func writeFilledTimecard(
        template: TimecardOfficialTemplate,
        productionTitle: String,
        occupation: String?,
        days: [CrewTimecardDay],
        workRecords: [WorkRecord],
        agreement: LaborAgreement,
        estimateByDayID: [UUID: SentinelPayEstimate],
        production: ProductionProject?
    ) throws -> URL {
        #if canImport(PDFKit)
        guard let templateURL = Bundle.main.url(
            forResource: template.bundleResourceName,
            withExtension: "pdf",
            subdirectory: "Resources/PayrollTemplates"
        ) ?? Bundle.main.url(forResource: template.bundleResourceName, withExtension: "pdf") else {
            throw ComposeError.templateMissing(template.bundleResourceName)
        }
        guard let document = PDFDocument(url: templateURL) else {
            throw ComposeError.templateMissing(template.bundleResourceName)
        }

        let compliance = PayrollComplianceProfileStore.profile

        switch template {
            case .epCanadaCrewWeekly:
            EPCanadaPDFFormFiller.fill(
                document: document,
                productionTitle: productionTitle,
                occupation: occupation,
                days: days,
                production: production,
                compliance: compliance
            )
            case .castAndCrewCrewCanada, .castAndCrewTalentToronto:
            CastAndCrewPDFFormFiller.fill(
                document: document,
                productionTitle: productionTitle,
                occupation: occupation,
                days: days,
                production: production,
                compliance: compliance
            )
        }

        _ = workRecords
        _ = agreement
        _ = estimateByDayID

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let stem = template.bundleResourceName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(stem)_filled_\(stamp).pdf")
        guard document.write(to: url) else {
            throw ComposeError.couldNotCreatePDF
        }
        return url
        #else
        throw ComposeError.couldNotCreatePDF
        #endif
    }
}
