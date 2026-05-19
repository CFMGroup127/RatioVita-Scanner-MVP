import SwiftData

/// Single source of truth for the on-disk **SwiftData** schema (app container + Sovereign restore sidecar).
enum LibrarySwiftDataSchema {
    /// Stable fingerprint for store-recovery messaging when the schema grows.
    static var schemaFingerprint: String {
        "v2026-05-19-vehicle-days-optional-migration"
    }

    static func makeSchema() -> Schema {
        Schema([
            Item.self,
            Receipt.self,
            ReceiptImage.self,
            ReceiptLineItem.self,
            WorkSession.self,
            WorkRecord.self,
            BankTransaction.self,
            LedgerBankAccount.self,
            ReceiptReferenceLink.self,
            ProductionProject.self,
            BusinessEntity.self,
            PreliminaryBusinessEntity.self,
            EquipmentAsset.self,
            ProductionKitCheckout.self,
            ProductionContact.self,
            CabinetFolder.self,
            ArcticVaultFolder.self,
            MerchantFilingRule.self,
            SovereignAuditLogEntry.self,
            LaborAgreement.self,
            ShowLaborPositionRate.self,
            CrewTimecardDay.self,
            RecordTombstone.self,
            ProductionProjectDeletionTombstone.self,
            MediaAsset.self,
            LyricSegment.self,
            MetadataCard.self,
            HistoricalKnowledgeNode.self,
            MaatDeclaration.self,
            MediaProductionBeat.self,
        ])
    }
}
