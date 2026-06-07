import Foundation
import SwiftData

/// Builds zero-chatter executive snapshot from live SetOS modules (Sprint VVV).
@MainActor
enum PMMacroMatrixAggregator {
    static func refreshSnapshot(context: ModelContext) throws -> ExecutiveLogisticsSnapshot {
        let crisisNodes = try context.fetch(FetchDescriptor<ProductionUnitCrisisNode>())
        let trailers = try context.fetch(FetchDescriptor<TrailerOperationalUnit>())
        let greenZones = try context.fetch(FetchDescriptor<LocationsGreenZone>())
        let callSheets = try context.fetch(FetchDescriptor<ProductionCallSheetDay>())

        let muskoka = crisisNodes.first { $0.unitNode == .secondUnitMuskoka }
        let snapshotDescriptor = FetchDescriptor<ExecutiveLogisticsSnapshot>()
        let existing = try context.fetch(snapshotDescriptor).first

        let snapshot = existing ?? ExecutiveLogisticsSnapshot()
        if existing == nil { context.insert(snapshot) }

        snapshot.crisisTier = muskoka?.crisisTier ?? .operationalWarning
        snapshot.activeCallSheetHeadcount = estimatedHeadcount(callSheets: callSheets)
        snapshot.requiredBedCapacity = snapshot.activeCallSheetHeadcount
        snapshot.securedHotelRoomsCount = greenZones.reduce(0) { $0 + $1.securedHotelRooms }
        snapshot.locationsGreenZonesTotal = max(greenZones.count, 5)
        snapshot.locationsGreenZonesSecured = greenZones.filter { $0.securedHotelRooms > 0 }.count

        let securedWardrobe = trailers.filter {
            $0.status.rawValue >= TrailerLogisticsState.wardrobeSecuredPendingClearance.rawValue
        }.count
        snapshot.hmwTrailersLocked = securedWardrobe >= max(1, trailers.count / 2)
        snapshot.castShuttlesAligned = true
        snapshot.gennyStandby = muskoka?.crisisTier == .activeEvacuation
        snapshot.transportFleetTotal = muskoka?.fleetTrailerCount ?? 30
        snapshot.transportFleetReadyCount = muskoka?.inboundDriverTokens.count ?? 0
        snapshot.inboundDriverCount = muskoka?.inboundDriverTokens.count ?? 0
        snapshot.updatedAt = .now

        try context.save()
        return snapshot
    }

    static func seedGreenZones(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<LocationsGreenZone>())
        if !existing.isEmpty { return }

        let zones = [
            LocationsGreenZone(
                zoneName: "Zone 1 · North corridor",
                securedHotelRooms: 42,
                requiredBedCapacity: 312
            ),
            LocationsGreenZone(
                zoneName: "Zone 2 · Lakeshore",
                securedHotelRooms: 18,
                requiredBedCapacity: 312
            ),
            LocationsGreenZone(
                zoneName: "Zone 3 · Jessica 2024 layout match",
                securedHotelRooms: 186,
                requiredBedCapacity: 312,
                isFavourable: true,
                overheadNotes: "Legacy trailer grid — favourable hotel block + access."
            ),
            LocationsGreenZone(zoneName: "Zone 4 · East industrial", securedHotelRooms: 0, requiredBedCapacity: 312),
            LocationsGreenZone(zoneName: "Zone 5 · South fallback", securedHotelRooms: 64, requiredBedCapacity: 312),
        ]
        zones[2].isSelectedForFocus = true
        for zone in zones {
            context.insert(zone)
        }
        try context.save()
    }

    private static func estimatedHeadcount(callSheets: [ProductionCallSheetDay]) -> Int {
        guard let latest = callSheets.sorted(by: { $0.sheetDate > $1.sheetDate }).first else {
            return 312
        }
        let hubs = latest.pickupHubs.count
        return 280 + hubs * 8
    }
}
