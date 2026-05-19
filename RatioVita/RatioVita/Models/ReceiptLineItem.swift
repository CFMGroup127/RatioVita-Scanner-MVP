import Foundation
import SwiftData

@Model
final class ReceiptLineItem {
    var id: UUID
    /// Order within the parent receipt (0-based).
    var sortIndex: Int
    var lineDescription: String
    var quantity: Int?
    var unitPrice: Decimal?
    var totalPrice: Decimal?
    var serialNumber: String?
    /// Optional barcode value (UPC/EAN/Code128/etc.) for future scan workflows.
    var barcodeValue: String?
    /// Optional RFID tag identifier for future asset tracking workflows.
    var rfidTag: String?
    /// Optional end date for warranty tracking on this line.
    var warrantyEndDate: Date?

    /// General ledger code suggestion (e.g. GL-5210-CRAFT).
    var glCode: String?

    /// Line-level business entity allocation (multi-entity receipts).
    var allocatedBusinessEntity: BusinessEntity?
    var allocatedProductionProject: ProductionProject?
    /// When true, line is personal / non-business (remainder waterfall default).
    var allocationIsPersonal: Bool

    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        sortIndex: Int = 0,
        lineDescription: String,
        quantity: Int? = nil,
        unitPrice: Decimal? = nil,
        totalPrice: Decimal? = nil,
        serialNumber: String? = nil,
        barcodeValue: String? = nil,
        rfidTag: String? = nil,
        warrantyEndDate: Date? = nil,
        glCode: String? = nil,
        allocatedBusinessEntity: BusinessEntity? = nil,
        allocatedProductionProject: ProductionProject? = nil,
        allocationIsPersonal: Bool = false,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.lineDescription = lineDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.serialNumber = serialNumber
        self.barcodeValue = barcodeValue
        self.rfidTag = rfidTag
        self.warrantyEndDate = warrantyEndDate
        self.glCode = glCode
        self.allocatedBusinessEntity = allocatedBusinessEntity
        self.allocatedProductionProject = allocatedProductionProject
        self.allocationIsPersonal = allocationIsPersonal
        self.receipt = receipt
    }
}
