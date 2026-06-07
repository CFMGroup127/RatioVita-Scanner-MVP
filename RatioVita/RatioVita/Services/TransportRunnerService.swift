import Foundation
import SwiftData

/// Digital transport runs, multi-leg dispatch, and 4 AM emergency shuttle mesh.
@MainActor
enum TransportRunnerService {
    enum GreenLightEvent: Sendable {
        case awaitingDeptHead
        case awaitingPM
        case awaitingDriverAssignment
        case greenLit(authorizationToken: String)
    }

    static func evaluatePMRequirement(
        ticket: RunRequestTicket,
        rules: ProductionApprovalRule
    ) -> Bool {
        if ticket.requiresPMApproval { return true }
        if ticket.estimatedTotalCAD > rules.pettyCashAutoApproveCAD { return true }
        if ticket.urgency == .castSpecialRequest { return true }
        return false
    }

    static func submitRunRequest(
        context: ModelContext,
        ticket: RunRequestTicket,
        rules: ProductionApprovalRule
    ) throws -> GreenLightEvent {
        ticket.requiresPMApproval = evaluatePMRequirement(ticket: ticket, rules: rules)
        ticket.updatedAt = .now
        context.insert(ticket)
        try context.save()
        return nextGreenLightState(ticket: ticket)
    }

    static func deptHeadApprove(
        context: ModelContext,
        ticket: RunRequestTicket,
        signerName _: String
    ) throws -> GreenLightEvent {
        ticket.isApprovedByDeptHead = true
        ticket.deptHeadSignedAt = .now
        ticket.updatedAt = .now
        try context.save()
        return nextGreenLightState(ticket: ticket)
    }

    static func pmApprove(
        context: ModelContext,
        ticket: RunRequestTicket
    ) throws -> GreenLightEvent {
        ticket.isApprovedByPM = true
        ticket.pmSignedAt = .now
        ticket.updatedAt = .now
        try context.save()
        return nextGreenLightState(ticket: ticket)
    }

    static func assignDriverAndGreenLight(
        context: ModelContext,
        ticket: RunRequestTicket,
        driverIdentifier: String
    ) throws -> GreenLightEvent {
        ticket.assignedDriverIdentifier = driverIdentifier
        ticket.cashetAuthorizationToken = "CASHET-\(ticket.id.uuidString.prefix(12).uppercased())"
        ticket.isGreenLit = true
        ticket.updatedAt = .now
        try context.save()
        return .greenLit(authorizationToken: ticket.cashetAuthorizationToken ?? "")
    }

    static func assignDepartmentRunner(
        context: ModelContext,
        ticket: RunRequestTicket,
        runnerIdentifier: String
    ) throws -> GreenLightEvent {
        ticket.assignedRunnerIdentifier = runnerIdentifier
        ticket.updatedAt = .now
        try context.save()
        if ticket.isApprovedByDeptHead, !ticket.requiresPMApproval || ticket.isApprovedByPM {
            ticket.cashetAuthorizationToken = "RUNNER-\(ticket.id.uuidString.prefix(12).uppercased())"
            ticket.isGreenLit = true
            try context.save()
            return .greenLit(authorizationToken: ticket.cashetAuthorizationToken ?? "")
        }
        return nextGreenLightState(ticket: ticket)
    }

    static func nextGreenLightState(ticket: RunRequestTicket) -> GreenLightEvent {
        if !ticket.isApprovedByDeptHead { return .awaitingDeptHead }
        if ticket.requiresPMApproval, !ticket.isApprovedByPM { return .awaitingPM }
        if ticket.isGreenLit, let token = ticket.cashetAuthorizationToken {
            return .greenLit(authorizationToken: token)
        }
        return .awaitingDriverAssignment
    }

    // MARK: - Multi-leg dispatch

    static func createMultiLegDispatch(
        context: ModelContext,
        productionProjectID: UUID?,
        vehicle: TransportVehicleScale,
        legs: [RouteLegPayload],
        driverID: String? = nil
    ) throws -> TransportDispatchTicket {
        let ticket = TransportDispatchTicket(
            productionProjectID: productionProjectID,
            requiredVehicleScale: vehicle,
            routeLegs: legs,
            isEmergencyShuttleRequest: false,
            requesterName: ""
        )
        ticket.assignedDriverID = driverID
        ticket.status = .inTransit
        context.insert(ticket)
        try context.save()
        return ticket
    }

    static func completeRouteLeg(
        context: ModelContext,
        ticket: TransportDispatchTicket,
        legID: UUID
    ) throws {
        var legs = ticket.routeLegs
        guard let idx = legs.firstIndex(where: { $0.id == legID }) else { return }
        legs[idx].isCompleted = true
        ticket.routeLegs = legs
        ticket.updatedAt = .now
        if legs.allSatisfy(\.isCompleted) {
            ticket.status = .delivered
        }
        try context.save()
    }

    /// 4 AM stranded daily — geofenced emergency shuttle at top of captain board.
    static func submitEmergencyShuttle(
        context: ModelContext,
        productionProjectID: UUID?,
        requesterName: String,
        geofenceAnchor: String,
        loadProfile: ShuttleLoadProfile
    ) throws -> TransportDispatchTicket {
        let vehicle: TransportVehicleScale = loadProfile == .mePlusHeavyRacks ? .cubeTruck : .passengerVan
        let ticket = TransportDispatchTicket(
            productionProjectID: productionProjectID,
            requiredVehicleScale: vehicle,
            routeLegs: [
                RouteLegPayload(
                    locationName: geofenceAnchor.isEmpty ? "Current location" : geofenceAnchor,
                    legDescription: "Emergency crew shuttle pickup"
                ),
                RouteLegPayload(
                    locationName: "Crew parking / wrap transport",
                    legDescription: "Drop at vehicles or transit hub"
                ),
            ],
            isEmergencyShuttleRequest: true,
            currentGeofenceAnchor: geofenceAnchor,
            loadProfile: loadProfile,
            requesterName: requesterName,
            status: .assigned
        )
        context.insert(ticket)
        try context.save()
        return ticket
    }

    static func sortedDispatchBoard(
        tickets: [TransportDispatchTicket]
    ) -> [TransportDispatchTicket] {
        tickets.sorted { lhs, rhs in
            if lhs.isEmergencyShuttleRequest != rhs.isEmergencyShuttleRequest {
                return lhs.isEmergencyShuttleRequest
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
