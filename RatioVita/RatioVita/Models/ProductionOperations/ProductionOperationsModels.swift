import Foundation
import SwiftData

// MARK: - Accounting rules (production-wide)

@Model
final class ProductionApprovalRule {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    /// Ice/milk/pop runs under this amount may skip PM (dept head still required).
    var pettyCashAutoApproveCAD: Decimal
    var poDeptHeadMaxCAD: Decimal
    var poRequiresPMAboveCAD: Decimal
    var poRequiresAccountingAboveCAD: Decimal
    var poRequiresExecutiveAboveCAD: Decimal
    var timesheetRequiresDeptHead: Bool
    var timesheetRequiresPM: Bool
    var timesheetRequiresAccounting: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        pettyCashAutoApproveCAD: Decimal = 50,
        poDeptHeadMaxCAD: Decimal = 500,
        poRequiresPMAboveCAD: Decimal = 500,
        poRequiresAccountingAboveCAD: Decimal = 5000,
        poRequiresExecutiveAboveCAD: Decimal = 15000,
        timesheetRequiresDeptHead: Bool = true,
        timesheetRequiresPM: Bool = true,
        timesheetRequiresAccounting: Bool = true,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        self.pettyCashAutoApproveCAD = pettyCashAutoApproveCAD
        self.poDeptHeadMaxCAD = poDeptHeadMaxCAD
        self.poRequiresPMAboveCAD = poRequiresPMAboveCAD
        self.poRequiresAccountingAboveCAD = poRequiresAccountingAboveCAD
        self.poRequiresExecutiveAboveCAD = poRequiresExecutiveAboveCAD
        self.timesheetRequiresDeptHead = timesheetRequiresDeptHead
        self.timesheetRequiresPM = timesheetRequiresPM
        self.timesheetRequiresAccounting = timesheetRequiresAccounting
        self.updatedAt = updatedAt
    }
}

// MARK: - Purchase orders

@Model
final class ProductionPurchaseOrder {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var vendorName: String
    var lineItemsSummary: String
    var totalAmountCAD: Decimal
    var submittedByRole: String
    var approvalStateRaw: Int
    var deptHeadSignerName: String?
    var deptHeadSignedAt: Date?
    var pmSignerName: String?
    var pmSignedAt: Date?
    var accountingSignerName: String?
    var accountingSignedAt: Date?
    var executiveSignerName: String?
    var executiveSignedAt: Date?
    var contextualNote: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        vendorName: String,
        lineItemsSummary: String,
        totalAmountCAD: Decimal,
        submittedByRole: String = "Coordinator",
        approvalState: ApprovalState = .drafted,
        contextualNote: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        self.vendorName = vendorName
        self.lineItemsSummary = lineItemsSummary
        self.totalAmountCAD = totalAmountCAD
        self.submittedByRole = submittedByRole
        approvalStateRaw = approvalState.rawValue
        self.contextualNote = contextualNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var approvalState: ApprovalState {
        get { ApprovalState(rawValue: approvalStateRaw) ?? .drafted }
        set { approvalStateRaw = newValue.rawValue }
    }
}

// MARK: - Craft supply catalog

@Model
final class CateringSupplyItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRaw: String
    var isStandardWarehouseStaple: Bool
    var requiresPMApproval: Bool
    var audienceTag: String
    var onHandQuantity: Int
    var reorderThreshold: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        categoryRaw: String = SupplyListKind.loadList.rawValue,
        isStandardWarehouseStaple: Bool = true,
        requiresPMApproval: Bool = false,
        audienceTag: String = "crew",
        onHandQuantity: Int = 0,
        reorderThreshold: Int = 5,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.categoryRaw = categoryRaw
        self.isStandardWarehouseStaple = isStandardWarehouseStaple
        self.requiresPMApproval = requiresPMApproval
        self.audienceTag = audienceTag
        self.onHandQuantity = onHandQuantity
        self.reorderThreshold = reorderThreshold
        self.updatedAt = updatedAt
    }

    var listKind: SupplyListKind {
        get { SupplyListKind(rawValue: categoryRaw) ?? .loadList }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - On-set run / shopping tickets

@Model
final class RunRequestTicket {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var requestingDepartment: String
    var requestedByName: String
    var requestedItemsJSON: String
    var urgencyRaw: String
    var contextualNote: String
    var estimatedTotalCAD: Decimal
    var requiresPMApproval: Bool
    var isApprovedByDeptHead: Bool
    var deptHeadSignedAt: Date?
    var isApprovedByPM: Bool
    var pmSignedAt: Date?
    var isGreenLit: Bool
    var assignedDriverIdentifier: String?
    var assignedRunnerIdentifier: String?
    var transportCaptainNotified: Bool
    var cashetAuthorizationToken: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        requestingDepartment: String,
        requestedByName: String = "",
        requestedItems: [String] = [],
        urgency: OrderUrgency = .setEmergencyRun,
        contextualNote: String = "",
        estimatedTotalCAD: Decimal = 0,
        requiresPMApproval: Bool = false
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        self.requestingDepartment = requestingDepartment
        self.requestedByName = requestedByName
        requestedItemsJSON = (try? String(data: JSONEncoder().encode(requestedItems), encoding: .utf8)) ?? "[]"
        urgencyRaw = urgency.rawValue
        self.contextualNote = contextualNote
        self.estimatedTotalCAD = estimatedTotalCAD
        self.requiresPMApproval = requiresPMApproval
        isApprovedByDeptHead = false
        isApprovedByPM = false
        isGreenLit = false
        transportCaptainNotified = false
        createdAt = .now
        updatedAt = .now
    }

    var urgency: OrderUrgency {
        get { OrderUrgency(rawValue: urgencyRaw) ?? .setEmergencyRun }
        set { urgencyRaw = newValue.rawValue }
    }

    var requestedItems: [String] {
        get {
            guard let data = requestedItemsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            requestedItemsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }
}

// MARK: - Multi-leg transport

struct RouteLegPayload: Codable, Identifiable, Sendable {
    var id: UUID
    var locationName: String
    var legDescription: String
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        locationName: String,
        legDescription: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.locationName = locationName
        self.legDescription = legDescription
        self.isCompleted = isCompleted
    }
}

@Model
final class TransportDispatchTicket {
    @Attribute(.unique) var id: UUID
    var productionProjectID: UUID?
    var assignedDriverID: String?
    var requiredVehicleScaleRaw: String
    var routeLegsJSON: String
    var isEmergencyShuttleRequest: Bool
    var currentGeofenceAnchor: String
    var loadProfileRaw: String
    var requesterName: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        productionProjectID: UUID? = nil,
        requiredVehicleScale: TransportVehicleScale = .passengerVan,
        routeLegs: [RouteLegPayload] = [],
        isEmergencyShuttleRequest: Bool = false,
        currentGeofenceAnchor: String = "",
        loadProfile: ShuttleLoadProfile = .solo,
        requesterName: String = "",
        status: ShuttleDeliveryStatus = .draft
    ) {
        self.id = id
        self.productionProjectID = productionProjectID
        requiredVehicleScaleRaw = requiredVehicleScale.rawValue
        routeLegsJSON = (try? String(data: JSONEncoder().encode(routeLegs), encoding: .utf8)) ?? "[]"
        self.isEmergencyShuttleRequest = isEmergencyShuttleRequest
        self.currentGeofenceAnchor = currentGeofenceAnchor
        loadProfileRaw = loadProfile.rawValue
        self.requesterName = requesterName
        statusRaw = status.rawValue
        createdAt = .now
        updatedAt = .now
    }

    var requiredVehicleScale: TransportVehicleScale {
        get { TransportVehicleScale(rawValue: requiredVehicleScaleRaw) ?? .passengerVan }
        set { requiredVehicleScaleRaw = newValue.rawValue }
    }

    var loadProfile: ShuttleLoadProfile {
        get { ShuttleLoadProfile(rawValue: loadProfileRaw) ?? .solo }
        set { loadProfileRaw = newValue.rawValue }
    }

    var status: ShuttleDeliveryStatus {
        get { ShuttleDeliveryStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var routeLegs: [RouteLegPayload] {
        get {
            guard let data = routeLegsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([RouteLegPayload].self, from: data) else { return [] }
            return decoded
        }
        set {
            routeLegsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }
}

// MARK: - Venue checkout / tips

@Model
final class VenueCheckoutSession {
    @Attribute(.unique) var id: UUID
    var hostName: String
    var guestCardIdentifiersJSON: String
    var foodSubtotalCAD: Decimal
    var gratuityCAD: Decimal
    var tipServerShareCAD: Decimal
    var tipBartenderShareCAD: Decimal
    var tipSupportShareCAD: Decimal
    var clearedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hostName: String,
        guestCardIdentifiers: [String] = [],
        foodSubtotalCAD: Decimal,
        gratuityCAD: Decimal,
        tipServerShareCAD: Decimal = 0,
        tipBartenderShareCAD: Decimal = 0,
        tipSupportShareCAD: Decimal = 0
    ) {
        self.id = id
        self.hostName = hostName
        guestCardIdentifiersJSON = (try? String(
            data: JSONEncoder().encode(guestCardIdentifiers),
            encoding: .utf8
        )) ?? "[]"
        self.foodSubtotalCAD = foodSubtotalCAD
        self.gratuityCAD = gratuityCAD
        self.tipServerShareCAD = tipServerShareCAD
        self.tipBartenderShareCAD = tipBartenderShareCAD
        self.tipSupportShareCAD = tipSupportShareCAD
        createdAt = .now
    }

    var guestCardIdentifiers: [String] {
        get {
            guard let data = guestCardIdentifiersJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guestCardIdentifiersJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }
}

/// Off-truck retail tap (Red Bull, etc.) — production-paid vs crew wallet.
@Model
final class CraftMicroPurchase {
    @Attribute(.unique) var id: UUID
    var itemTitle: String
    var amountCAD: Decimal
    var paidByProduction: Bool
    var crewMemberName: String
    var walletTransactionRef: String?
    var createdAt: Date

    init(
        itemTitle: String,
        amountCAD: Decimal,
        paidByProduction: Bool = false,
        crewMemberName: String = "",
        walletTransactionRef: String? = nil
    ) {
        id = UUID()
        self.itemTitle = itemTitle
        self.amountCAD = amountCAD
        self.paidByProduction = paidByProduction
        self.crewMemberName = crewMemberName
        self.walletTransactionRef = walletTransactionRef
        createdAt = .now
    }
}
