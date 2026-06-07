//
//  NewHorizonsEstateModels.swift
//  RatioVita
//
//  New Horizons — Estate Technical Database Structures (first iteration).
//
//  These SwiftData models are the unified core for the New Horizons estate:
//   • `TelemetryReading`      — geothermal / solar / off-grid power + sensor telemetry.
//   • `VerticalFarmingLog`    — local agricultural yields and grow-automation metrics.
//   • `CuratedAsset`          — high-value physical asset provenance + document attachments
//                               (expands the existing `EquipmentAsset` inventory concept toward
//                               appraisable, chain-of-custody assets).
//
//  Convention notes (match the rest of the library schema):
//   • `@Attribute(.unique) var id: UUID`, `createdAt` / `updatedAt: Date`.
//   • Currency as `Decimal`; sensor magnitudes as `Double`.
//   • Enums are persisted as raw `String` (`...Raw`) with typed computed accessors so the
//     on-disk store stays migration- and CloudKit-friendly.
//   • Physical location uses the shared `NewHorizonsZoneCatalog` zone tags.
//
//  Remember to register every new `@Model` in `LibrarySwiftDataSchema.makeSchema()`.
//

import Foundation
import SwiftData

// MARK: - TelemetryReading

/// A single time-stamped measurement from an estate energy / environment source
/// (geothermal loop, solar array, battery bank, generator, grid tie, water, etc.).
@Model
final class TelemetryReading {
    @Attribute(.unique) var id: UUID
    /// Instant the measurement was captured (sensor clock, not insert time).
    var measuredAt: Date
    /// Raw backing for `source`.
    var sourceRaw: String
    /// Raw backing for `metric`.
    var metricRaw: String
    /// Numeric magnitude in `unit` (e.g. 6.4 for 6.4 kW).
    var value: Double
    /// Raw backing for `unit`.
    var unitRaw: String
    /// True when the value is interpolated / modelled rather than directly sampled.
    var isEstimated: Bool
    /// Optional physical zone (see `NewHorizonsZoneCatalog`).
    var physicalZoneTag: String?
    /// Hardware identifier of the inverter / sensor / meter that produced the reading.
    var deviceIdentifier: String?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        measuredAt: Date = .now,
        source: TelemetrySource,
        metric: TelemetryMetric,
        value: Double,
        unit: TelemetryUnit,
        isEstimated: Bool = false,
        physicalZoneTag: String? = nil,
        deviceIdentifier: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.measuredAt = measuredAt
        sourceRaw = source.rawValue
        metricRaw = metric.rawValue
        self.value = value
        unitRaw = unit.rawValue
        self.isEstimated = isEstimated
        self.physicalZoneTag = physicalZoneTag
        self.deviceIdentifier = deviceIdentifier
        self.notes = notes
        self.createdAt = createdAt
    }

    var source: TelemetrySource {
        get { TelemetrySource(rawValue: sourceRaw) ?? .other }
        set { sourceRaw = newValue.rawValue }
    }

    var metric: TelemetryMetric {
        get { TelemetryMetric(rawValue: metricRaw) ?? .other }
        set { metricRaw = newValue.rawValue }
    }

    var unit: TelemetryUnit {
        get { TelemetryUnit(rawValue: unitRaw) ?? .unitless }
        set { unitRaw = newValue.rawValue }
    }
}

enum TelemetrySource: String, CaseIterable, Codable, Sendable {
    case geothermal
    case solar
    case wind
    case battery
    case generator
    case gridTie
    case water
    case hvac
    case other

    var displayName: String {
        switch self {
            case .geothermal: "Geothermal Loop"
            case .solar: "Solar Array"
            case .wind: "Wind Turbine"
            case .battery: "Battery Bank"
            case .generator: "Backup Generator"
            case .gridTie: "Grid Tie"
            case .water: "Water System"
            case .hvac: "HVAC"
            case .other: "Other"
        }
    }
}

enum TelemetryMetric: String, CaseIterable, Codable, Sendable {
    case powerGeneration
    case powerConsumption
    case stateOfCharge
    case temperature
    case flowRate
    case voltage
    case current
    case humidity
    case other

    var displayName: String {
        switch self {
            case .powerGeneration: "Power Generation"
            case .powerConsumption: "Power Consumption"
            case .stateOfCharge: "State of Charge"
            case .temperature: "Temperature"
            case .flowRate: "Flow Rate"
            case .voltage: "Voltage"
            case .current: "Current"
            case .humidity: "Humidity"
            case .other: "Other"
        }
    }
}

enum TelemetryUnit: String, CaseIterable, Codable, Sendable {
    case kilowatt = "kW"
    case kilowattHour = "kWh"
    case percent = "%"
    case celsius = "°C"
    case litersPerMinute = "L/min"
    case volt = "V"
    case ampere = "A"
    case unitless = ""
}

// MARK: - VerticalFarmingLog

/// A grow-cycle observation for the estate's vertical farming / greenhouse program:
/// captures both harvest yield and the automation envelope (water, light, climate, energy).
@Model
final class VerticalFarmingLog {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    /// Optional physical zone (e.g. "Floor 6 Roof Shelf — Greenhouse Terrace").
    var physicalZoneTag: String?
    var cropName: String
    /// Raw backing for `cropCategory`.
    var cropCategoryRaw: String
    /// Raw backing for `growthStage`.
    var growthStageRaw: String

    // Yield
    var harvestWeightGrams: Double?
    var unitsHarvested: Int?

    // Automation / climate envelope
    var waterUsageLiters: Double?
    var nutrientDoseMilliliters: Double?
    var lightHours: Double?
    var ambientTemperatureCelsius: Double?
    var humidityPercent: Double?
    var co2PartsPerMillion: Double?
    var energyUsedKilowattHours: Double?

    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        physicalZoneTag: String? = nil,
        cropName: String,
        cropCategory: CropCategory = .other,
        growthStage: GrowthStage = .vegetative,
        harvestWeightGrams: Double? = nil,
        unitsHarvested: Int? = nil,
        waterUsageLiters: Double? = nil,
        nutrientDoseMilliliters: Double? = nil,
        lightHours: Double? = nil,
        ambientTemperatureCelsius: Double? = nil,
        humidityPercent: Double? = nil,
        co2PartsPerMillion: Double? = nil,
        energyUsedKilowattHours: Double? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.physicalZoneTag = physicalZoneTag
        self.cropName = cropName
        cropCategoryRaw = cropCategory.rawValue
        growthStageRaw = growthStage.rawValue
        self.harvestWeightGrams = harvestWeightGrams
        self.unitsHarvested = unitsHarvested
        self.waterUsageLiters = waterUsageLiters
        self.nutrientDoseMilliliters = nutrientDoseMilliliters
        self.lightHours = lightHours
        self.ambientTemperatureCelsius = ambientTemperatureCelsius
        self.humidityPercent = humidityPercent
        self.co2PartsPerMillion = co2PartsPerMillion
        self.energyUsedKilowattHours = energyUsedKilowattHours
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var cropCategory: CropCategory {
        get { CropCategory(rawValue: cropCategoryRaw) ?? .other }
        set { cropCategoryRaw = newValue.rawValue }
    }

    var growthStage: GrowthStage {
        get { GrowthStage(rawValue: growthStageRaw) ?? .vegetative }
        set { growthStageRaw = newValue.rawValue }
    }

    /// Grams harvested per kWh consumed — a simple yield-efficiency signal for the program.
    var gramsPerKilowattHour: Double? {
        guard let weight = harvestWeightGrams,
              let energy = energyUsedKilowattHours, energy > 0 else { return nil }
        return weight / energy
    }
}

enum CropCategory: String, CaseIterable, Codable, Sendable {
    case leafyGreens
    case herbs
    case fruiting
    case microgreens
    case roots
    case flowers
    case other

    var displayName: String {
        switch self {
            case .leafyGreens: "Leafy Greens"
            case .herbs: "Herbs"
            case .fruiting: "Fruiting"
            case .microgreens: "Microgreens"
            case .roots: "Roots & Tubers"
            case .flowers: "Edible Flowers"
            case .other: "Other"
        }
    }
}

enum GrowthStage: String, CaseIterable, Codable, Sendable {
    case seeding
    case germination
    case vegetative
    case flowering
    case fruiting
    case harvest

    var displayName: String {
        switch self {
            case .seeding: "Seeding"
            case .germination: "Germination"
            case .vegetative: "Vegetative"
            case .flowering: "Flowering"
            case .fruiting: "Fruiting"
            case .harvest: "Harvest"
        }
    }
}

// MARK: - CuratedAsset

/// A high-value, appraisable physical asset (artwork, furnishings, vehicles, instruments,
/// collectibles, estate fixtures). Unlike `EquipmentAsset` (kit / gear rentals), a curated
/// asset tracks valuation, provenance chain-of-custody, and supporting document attachments.
@Model
final class CuratedAsset {
    @Attribute(.unique) var id: UUID
    var displayName: String
    /// Raw backing for `category`.
    var categoryRaw: String
    var assetDescription: String?

    // Maker / identity
    var artistOrMaker: String?
    var yearCreated: String?
    var serialOrEdition: String?

    // Acquisition & valuation (CAD)
    var acquisitionDate: Date?
    var acquisitionCostCAD: Decimal?
    var currentValuationCAD: Decimal?
    var valuationDate: Date?

    // Insurance
    var isInsured: Bool
    var insurancePolicyNumber: String?

    // Location & provenance summary
    var physicalZoneTag: String?
    var provenanceSummary: String?

    var createdAt: Date
    var updatedAt: Date

    /// Supporting documents (appraisals, certificates, bills of sale, photos).
    @Relationship(deleteRule: .cascade, inverse: \CuratedAssetDocument.asset)
    var documents: [CuratedAssetDocument]

    /// Ordered chain-of-custody / valuation history.
    @Relationship(deleteRule: .cascade, inverse: \CuratedAssetProvenanceEvent.asset)
    var provenanceEvents: [CuratedAssetProvenanceEvent]

    init(
        id: UUID = UUID(),
        displayName: String,
        category: CuratedAssetCategory = .other,
        assetDescription: String? = nil,
        artistOrMaker: String? = nil,
        yearCreated: String? = nil,
        serialOrEdition: String? = nil,
        acquisitionDate: Date? = nil,
        acquisitionCostCAD: Decimal? = nil,
        currentValuationCAD: Decimal? = nil,
        valuationDate: Date? = nil,
        isInsured: Bool = false,
        insurancePolicyNumber: String? = nil,
        physicalZoneTag: String? = nil,
        provenanceSummary: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        documents: [CuratedAssetDocument] = [],
        provenanceEvents: [CuratedAssetProvenanceEvent] = []
    ) {
        self.id = id
        self.displayName = displayName
        categoryRaw = category.rawValue
        self.assetDescription = assetDescription
        self.artistOrMaker = artistOrMaker
        self.yearCreated = yearCreated
        self.serialOrEdition = serialOrEdition
        self.acquisitionDate = acquisitionDate
        self.acquisitionCostCAD = acquisitionCostCAD
        self.currentValuationCAD = currentValuationCAD
        self.valuationDate = valuationDate
        self.isInsured = isInsured
        self.insurancePolicyNumber = insurancePolicyNumber
        self.physicalZoneTag = physicalZoneTag
        self.provenanceSummary = provenanceSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.documents = documents
        self.provenanceEvents = provenanceEvents
    }

    var category: CuratedAssetCategory {
        get { CuratedAssetCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Unrealized gain/loss versus acquisition cost (nil if either figure is unknown).
    var unrealizedGainCAD: Decimal? {
        guard let cost = acquisitionCostCAD, let value = currentValuationCAD else { return nil }
        return value - cost
    }
}

enum CuratedAssetCategory: String, CaseIterable, Codable, Sendable {
    case artwork
    case furniture
    case vehicle
    case jewelry
    case timepiece
    case wineAndSpirits
    case instrument
    case collectible
    case realEstateFixture
    case other

    var displayName: String {
        switch self {
            case .artwork: "Artwork"
            case .furniture: "Furniture"
            case .vehicle: "Vehicle"
            case .jewelry: "Jewelry"
            case .timepiece: "Timepiece"
            case .wineAndSpirits: "Wine & Spirits"
            case .instrument: "Instrument"
            case .collectible: "Collectible"
            case .realEstateFixture: "Real-Estate Fixture"
            case .other: "Other"
        }
    }
}

/// A document attachment for a `CuratedAsset` (bytes stored inline for portability,
/// matching the `ReceiptImage` persistence pattern).
@Model
final class CuratedAssetDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Raw backing for `kind`.
    var kindRaw: String
    var fileName: String?
    var mimeType: String?
    /// Inline file bytes (PDF / image / certificate). Optional so a placeholder row can exist
    /// before the binary is imported.
    @Attribute(.externalStorage) var fileData: Data?
    var createdAt: Date

    @Relationship var asset: CuratedAsset?

    init(
        id: UUID = UUID(),
        title: String,
        kind: CuratedAssetDocumentKind = .other,
        fileName: String? = nil,
        mimeType: String? = nil,
        fileData: Data? = nil,
        createdAt: Date = .now,
        asset: CuratedAsset? = nil
    ) {
        self.id = id
        self.title = title
        kindRaw = kind.rawValue
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileData = fileData
        self.createdAt = createdAt
        self.asset = asset
    }

    var kind: CuratedAssetDocumentKind {
        get { CuratedAssetDocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

enum CuratedAssetDocumentKind: String, CaseIterable, Codable, Sendable {
    case appraisal
    case certificate
    case billOfSale
    case insurance
    case photo
    case provenanceRecord
    case other

    var displayName: String {
        switch self {
            case .appraisal: "Appraisal"
            case .certificate: "Certificate of Authenticity"
            case .billOfSale: "Bill of Sale"
            case .insurance: "Insurance"
            case .photo: "Photograph"
            case .provenanceRecord: "Provenance Record"
            case .other: "Other"
        }
    }
}

/// A single chain-of-custody / valuation event in a `CuratedAsset`'s history.
@Model
final class CuratedAssetProvenanceEvent {
    @Attribute(.unique) var id: UUID
    var date: Date
    /// Raw backing for `eventType`.
    var eventTypeRaw: String
    /// Counterparty / appraiser / gallery / owner involved in the event.
    var party: String?
    var detail: String?
    var valuationCAD: Decimal?
    var createdAt: Date

    @Relationship var asset: CuratedAsset?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        eventType: CuratedAssetProvenanceEventType = .other,
        party: String? = nil,
        detail: String? = nil,
        valuationCAD: Decimal? = nil,
        createdAt: Date = .now,
        asset: CuratedAsset? = nil
    ) {
        self.id = id
        self.date = date
        eventTypeRaw = eventType.rawValue
        self.party = party
        self.detail = detail
        self.valuationCAD = valuationCAD
        self.createdAt = createdAt
        self.asset = asset
    }

    var eventType: CuratedAssetProvenanceEventType {
        get { CuratedAssetProvenanceEventType(rawValue: eventTypeRaw) ?? .other }
        set { eventTypeRaw = newValue.rawValue }
    }
}

enum CuratedAssetProvenanceEventType: String, CaseIterable, Codable, Sendable {
    case acquired
    case appraised
    case restored
    case authenticated
    case exhibited
    case loaned
    case transferred
    case sold
    case other

    var displayName: String {
        switch self {
            case .acquired: "Acquired"
            case .appraised: "Appraised"
            case .restored: "Restored"
            case .authenticated: "Authenticated"
            case .exhibited: "Exhibited"
            case .loaned: "Loaned"
            case .transferred: "Transferred"
            case .sold: "Sold"
            case .other: "Other"
        }
    }
}
