//
//  NewHorizonsSampleDataGenerator.swift
//  RatioVita
//
//  Seeds Burlington estate sample data into TelemetryReading, VerticalFarmingLog,
//  and CuratedAsset SwiftData models. Stable UUIDs in NewHorizonsSampleAssetID
//  are shared with VitaLogic's valuation generator for cross-repo handoff tests.
//

import Foundation
import SwiftData

/// Stable curated-asset UUIDs used by VitaLogic `AssetValuationSnapshot` handoff seeds.
enum NewHorizonsSampleAssetID {
    static let heritageChandelier = UUID(uuidString: "A1000001-0001-4001-8001-000000000001")!
    static let bronzeSculpture = UUID(uuidString: "A1000002-0002-4002-8002-000000000002")!
    static let geothermalManifold = UUID(uuidString: "A1000003-0003-4003-8003-000000000003")!
}

struct NewHorizonsSeedSummary: Sendable {
    let telemetryReadings: Int
    let farmingLogs: Int
    let curatedAssets: Int
}

enum NewHorizonsSampleDataGenerator {
    private static let seededKey = "com.ratiovita.newHorizonsSampleDataSeeded"

    /// Idempotent seed for the Burlington waterfront estate program.
    @MainActor
    static func seedBurlingtonEstateIfNeeded(modelContext: ModelContext) throws -> NewHorizonsSeedSummary {
        if UserDefaults.standard.bool(forKey: seededKey) {
            let existing = try countExisting(modelContext: modelContext)
            if existing.telemetry + existing.farming + existing.assets > 0 {
                return NewHorizonsSeedSummary(
                    telemetryReadings: existing.telemetry,
                    farmingLogs: existing.farming,
                    curatedAssets: existing.assets
                )
            }
        }

        let telemetry = try insertTelemetryWeekend(modelContext: modelContext)
        let farming = try insertFarmingCycles(modelContext: modelContext)
        let assets = try insertCuratedAssets(modelContext: modelContext)
        try modelContext.save()

        UserDefaults.standard.set(true, forKey: seededKey)
        return NewHorizonsSeedSummary(
            telemetryReadings: telemetry,
            farmingLogs: farming,
            curatedAssets: assets
        )
    }

    /// Forces a fresh seed (clears prior New Horizons rows with matching device IDs / asset IDs).
    @MainActor
    static func reseedBurlingtonEstate(modelContext: ModelContext) throws -> NewHorizonsSeedSummary {
        UserDefaults.standard.set(false, forKey: seededKey)
        try purgeExisting(modelContext: modelContext)
        return try seedBurlingtonEstateIfNeeded(modelContext: modelContext)
    }

    // MARK: - Telemetry (weekend curves)

    @MainActor
    private static func insertTelemetryWeekend(modelContext: ModelContext) throws -> Int {
        let calendar = Calendar.current
        // Anchor ~72h before today midnight as the weekend window start (deterministic seed window).
        let saturday = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: Date())) ?? Date()
        let zone = "Burlington Estate — Geothermal Plant"
        let solarZone = "Burlington Estate — South Array"
        var count = 0

        // 2-hour intervals, 60 hours (Sat 00:00 → Mon 12:00)
        for interval in 0..<30 {
            let hoursOffset = interval * 2
            guard let measuredAt = calendar.date(byAdding: .hour, value: hoursOffset, to: saturday) else { continue }
            let hour = calendar.component(.hour, from: measuredAt)

            let solarKW = solarGenerationKW(hour: hour)
            let loadKW = consumptionKW(hour: hour)
            let soc = batteryStateOfCharge(hour: hour, solar: solarKW, load: loadKW)

            modelContext.insert(TelemetryReading(
                measuredAt: measuredAt,
                source: .solar,
                metric: .powerGeneration,
                value: solarKW,
                unit: .kilowatt,
                physicalZoneTag: solarZone,
                deviceIdentifier: "burlington-solar-inv-01"
            ))
            count += 1

            modelContext.insert(TelemetryReading(
                measuredAt: measuredAt,
                source: .gridTie,
                metric: .powerConsumption,
                value: loadKW,
                unit: .kilowatt,
                physicalZoneTag: "Burlington Estate — Main Residence",
                deviceIdentifier: "burlington-main-panel"
            ))
            count += 1

            modelContext.insert(TelemetryReading(
                measuredAt: measuredAt,
                source: .battery,
                metric: .stateOfCharge,
                value: soc,
                unit: .percent,
                physicalZoneTag: "Burlington Estate — Battery Bank",
                deviceIdentifier: "burlington-lfp-bank-a"
            ))
            count += 1

            if interval % 2 == 0 {
                let flow = 42.0 + Double(interval % 5) * 0.8
                modelContext.insert(TelemetryReading(
                    measuredAt: measuredAt,
                    source: .geothermal,
                    metric: .flowRate,
                    value: flow,
                    unit: .litersPerMinute,
                    physicalZoneTag: zone,
                    deviceIdentifier: "burlington-geo-loop-primary"
                ))
                count += 1
            }
        }
        return count
    }

    private static func solarGenerationKW(hour: Int) -> Double {
        guard hour >= 6, hour <= 20 else { return 0.05 }
        let peak = 11.4 * sin(Double(hour - 6) * .pi / 14.0)
        return max(0.1, peak)
    }

    private static func consumptionKW(hour: Int) -> Double {
        var base = 2.8
        if (7...9).contains(hour) { base += 1.6 }
        if (17...22).contains(hour) { base += 2.1 }
        if hour >= 23 || hour <= 5 { base -= 0.9 }
        return max(1.2, base)
    }

    private static func batteryStateOfCharge(hour: Int, solar: Double, load: Double) -> Double {
        let net = solar - load
        let base = 58.0 + Double(hour) * 0.4
        let adjust = net * 2.5
        return min(98, max(22, base + adjust))
    }

    // MARK: - Vertical farming

    @MainActor
    private static func insertFarmingCycles(modelContext: ModelContext) throws -> Int {
        let greenhouse = "Floor 6 Roof Shelf — Greenhouse Terrace"
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())

        let cycles: [(String, CropCategory, GrowthStage, Double, Double, Int)] = [
            ("Butter Lettuce", .leafyGreens, .harvest, 2840, 18.2, 14),
            ("Genovese Basil", .herbs, .harvest, 1260, 9.4, 22),
            ("Micro Arugula", .microgreens, .harvest, 680, 4.1, 40),
            ("Heritage Cherry Tomato", .fruiting, .vegetative, 0, 11.8, 0),
        ]

        for (index, cycle) in cycles.enumerated() {
            let loggedAt = calendar.date(byAdding: .day, value: -(cycles.count - index), to: base) ?? base
            modelContext.insert(VerticalFarmingLog(
                loggedAt: loggedAt,
                physicalZoneTag: greenhouse,
                cropName: cycle.0,
                cropCategory: cycle.1,
                growthStage: cycle.2,
                harvestWeightGrams: cycle.3 > 0 ? cycle.3 : nil,
                unitsHarvested: cycle.5 > 0 ? cycle.5 : nil,
                waterUsageLiters: 48 + Double(index) * 6,
                nutrientDoseMilliliters: 120 + Double(index) * 15,
                lightHours: 14.5,
                ambientTemperatureCelsius: 21.5 + Double(index) * 0.3,
                humidityPercent: 62 + Double(index),
                co2PartsPerMillion: 780,
                energyUsedKilowattHours: cycle.4,
                notes: "Burlington estate vertical farm cycle \(index + 1)"
            ))
        }
        return cycles.count
    }

    // MARK: - Curated assets

    @MainActor
    private static func insertCuratedAssets(modelContext: ModelContext) throws -> Int {
        let assets: [CuratedAsset] = [
            CuratedAsset(
                id: NewHorizonsSampleAssetID.heritageChandelier,
                displayName: "Heritage Copper Chandelier",
                category: .realEstateFixture,
                assetDescription: "Original waterfront residence fixture, restored 2024",
                artistOrMaker: "Atelier Lumière",
                yearCreated: "1928",
                acquisitionDate: date(y: 2024, m: 3, d: 15),
                acquisitionCostCAD: Decimal(18500),
                currentValuationCAD: Decimal(24200),
                valuationDate: date(y: 2026, m: 1, d: 10),
                isInsured: true,
                insurancePolicyNumber: "NH-EST-CH-001",
                physicalZoneTag: "Burlington Estate — Main Residence",
                provenanceSummary: "Acquired from estate liquidation; documented restoration invoices on file."
            ),
            CuratedAsset(
                id: NewHorizonsSampleAssetID.bronzeSculpture,
                displayName: "Waterfront Bronze — Dawn Fisher",
                category: .artwork,
                assetDescription: "Limited cast 3/12, lakeshore commission series",
                artistOrMaker: "Elena Marchetti",
                yearCreated: "2019",
                acquisitionDate: date(y: 2025, m: 6, d: 2),
                acquisitionCostCAD: Decimal(42000),
                currentValuationCAD: Decimal(51500),
                valuationDate: date(y: 2026, m: 2, d: 20),
                isInsured: true,
                physicalZoneTag: "Burlington Estate — Lakeshore Garden",
                provenanceSummary: "Gallery certificate; condition report 2025."
            ),
            CuratedAsset(
                id: NewHorizonsSampleAssetID.geothermalManifold,
                displayName: "Geothermal Manifold Assembly",
                category: .realEstateFixture,
                assetDescription: "Primary loop manifold — estate infrastructure",
                artistOrMaker: "GeoTherm Systems",
                serialOrEdition: "GT-BURL-2025-MF-01",
                acquisitionDate: date(y: 2025, m: 9, d: 1),
                acquisitionCostCAD: Decimal(86000),
                currentValuationCAD: Decimal(86000),
                valuationDate: date(y: 2025, m: 9, d: 1),
                physicalZoneTag: "Burlington Estate — Geothermal Plant",
                provenanceSummary: "Capital install; Ash Roy telemetry binding active."
            ),
        ]

        for asset in assets {
            modelContext.insert(asset)
        }
        return assets.count
    }

    // MARK: - Helpers

    private static func date(y: Int, m: Int, d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    @MainActor
    private static func countExisting(modelContext: ModelContext) throws
        -> (telemetry: Int, farming: Int, assets: Int)
    {
        let t = try modelContext.fetchCount(FetchDescriptor<TelemetryReading>())
        let f = try modelContext.fetchCount(FetchDescriptor<VerticalFarmingLog>())
        let a = try modelContext.fetchCount(FetchDescriptor<CuratedAsset>())
        return (t, f, a)
    }

    @MainActor
    private static func purgeExisting(modelContext: ModelContext) throws {
        for reading in try modelContext.fetch(FetchDescriptor<TelemetryReading>()) {
            modelContext.delete(reading)
        }
        for log in try modelContext.fetch(FetchDescriptor<VerticalFarmingLog>()) {
            modelContext.delete(log)
        }
        for asset in try modelContext.fetch(FetchDescriptor<CuratedAsset>()) {
            modelContext.delete(asset)
        }
        try modelContext.save()
    }
}
