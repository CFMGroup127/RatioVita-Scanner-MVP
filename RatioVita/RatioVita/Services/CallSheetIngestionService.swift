import Foundation
import SwiftData

/// Harvests call sheet OCR into production day packages + transport waypoints.
@MainActor
enum CallSheetIngestionService {
    struct IngestResult: Sendable {
        var sheet: ProductionCallSheetDay
        var waypoints: [LocationWaypointPayload]
    }

    @discardableResult
    static func ingestFromOCR(
        context: ModelContext,
        ocrText: String,
        anchorDay: Date,
        productionProjectID: UUID?
    ) throws -> IngestResult? {
        guard let prefill = CallSheetHeaderParser.parseLaborPrefill(
            combinedOCR: ocrText,
            anchorDayIfNoDateInOCR: anchorDay
        ) else { return nil }

        let locations = extractLocationLines(from: ocrText)
        let pickups = extractPickupHubs(from: ocrText)
        let safety = extractSafetyLines(from: ocrText)
        let rain = ocrText.lowercased().contains("rain day")
        let insurance = ocrText.lowercased().contains("insurance day")

        let sheet = ProductionCallSheetDay(
            productionProjectID: productionProjectID,
            sheetDate: prefill.anchorDay,
            productionTitle: prefill.productionTitleLine ?? "",
            mainLocationName: prefill.setLocationLine ?? locations.first ?? "Main location",
            crewCallHour: prefill.crewCallHour,
            crewCallMinute: prefill.crewCallMinute,
            pickupHubs: pickups,
            safetyNotes: safety,
            isRainDay: rain,
            isInsuranceDay: insurance,
            distributedAt: .now
        )
        context.insert(sheet)

        var waypoints: [LocationWaypointPayload] = []
        for (idx, name) in locations.enumerated() {
            let coord = approximateCoordinate(for: name, index: idx)
            waypoints.append(
                LocationWaypointPayload(
                    name: name,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    sequenceOrder: idx
                )
            )
        }

        try context.save()

        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Call sheet distributed",
            body: "\(sheet.productionTitle) · \(sheet.mainLocationName) · crew call \(prefill.crewCallHour):\(String(format: "%02d", prefill.crewCallMinute))",
            senderRole: "2nd AD",
            priority: .callSheetDistribution
        )

        return IngestResult(sheet: sheet, waypoints: waypoints)
    }

    static func distributeRainDay(
        context: ModelContext,
        sheet: ProductionCallSheetDay,
        agreementCode: String = "IATSE"
    ) throws -> LaborGraceWindowCalculator.RainDayResult {
        sheet.isRainDay = true
        sheet.distributedAt = .now
        let result = LaborGraceWindowCalculator.evaluateCancellation(
            callDate: sheet.sheetDate,
            cancelledAt: .now,
            agreementCode: agreementCode
        )
        try HierarchyCommsEngine.ingest(
            context: context,
            title: "Rain day / schedule change",
            body: result.summary,
            senderRole: "PM",
            priority: .infrastructureCritical
        )
        try context.save()
        return result
    }

    private static func extractLocationLines(from ocr: String) -> [String] {
        var found: [String] = []
        for line in ocr.split(whereSeparator: \.isNewline) {
            let t = String(line).trimmingCharacters(in: .whitespaces)
            let low = t.lowercased()
            if low.contains("location") || low.contains("unwin") || low.contains("kipling")
                || low.contains("hearn") || low.contains("broadview")
            {
                if let colon = t.firstIndex(of: ":") {
                    let tail = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !tail.isEmpty { found.append(tail) }
                } else if !t.isEmpty {
                    found.append(t)
                }
            }
        }
        return Array(Set(found)).sorted()
    }

    private static func extractPickupHubs(from ocr: String) -> [String] {
        let lower = ocr.lowercased()
        var hubs: [String] = []
        if lower.contains("broadview") { hubs.append("Broadview Station pickup") }
        if lower.contains("danforth") { hubs.append("Danforth & Broadview") }
        if lower.contains("kipling") { hubs.append("777 Kipling — Production office") }
        return hubs
    }

    private static func extractSafetyLines(from ocr: String) -> [String] {
        ocr.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.lowercased().contains("safety") || $0.lowercased().contains("drone") }
    }

    /// Toronto-area seed coords for simulation until map geocode is wired.
    private static func approximateCoordinate(for name: String, index: Int) -> (latitude: Double, longitude: Double) {
        let low = name.lowercased()
        if low.contains("broadview") || low.contains("danforth") { return (43.677, -79.357) }
        if low.contains("kipling") { return (43.648, -79.532) }
        if low.contains("unwin") || low.contains("hearn") { return (43.655, -79.355) }
        if low.contains("four seasons") { return (43.672, -79.395) }
        return (43.65 + Double(index) * 0.002, -79.38 - Double(index) * 0.003)
    }
}
