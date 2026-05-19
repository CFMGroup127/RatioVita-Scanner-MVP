import Foundation
import SwiftData

/// DEBUG-only destructive reset for a **clean library** before importing a canonical 2020–2026 archive.
@MainActor
enum LibraryDeveloperReset {
    static func purgeEntirePersistentLibrary(modelContext: ModelContext) throws {
        try modelContext.save()

        func deleteAll<T: PersistentModel>(_: T.Type) throws {
            let fd = FetchDescriptor<T>()
            let rows = try modelContext.fetch(fd)
            for row in rows {
                modelContext.delete(row)
            }
        }

        try deleteAll(Receipt.self)
        try deleteAll(WorkSession.self)
        try deleteAll(WorkRecord.self)
        try deleteAll(ReceiptLineItem.self)
        try deleteAll(ReceiptImage.self)
        try deleteAll(BankTransaction.self)
        try deleteAll(ReceiptReferenceLink.self)
        try deleteAll(CrewTimecardDay.self)
        try deleteAll(ShowLaborPositionRate.self)
        try deleteAll(LaborAgreement.self)
        try deleteAll(ProductionProject.self)
        try deleteAll(BusinessEntity.self)
        try deleteAll(PreliminaryBusinessEntity.self)
        try deleteAll(EquipmentAsset.self)
        try deleteAll(ProductionKitCheckout.self)
        try deleteAll(ProductionContact.self)
        try deleteAll(CabinetFolder.self)
        try deleteAll(ArcticVaultFolder.self)
        try deleteAll(MerchantFilingRule.self)
        try deleteAll(SovereignAuditLogEntry.self)
        try deleteAll(RecordTombstone.self)
        try deleteAll(ProductionProjectDeletionTombstone.self)
        try deleteAll(LyricSegment.self)
        try deleteAll(MetadataCard.self)
        try deleteAll(MediaAsset.self)
        try deleteAll(MaatDeclaration.self)
        try deleteAll(HistoricalKnowledgeNode.self)
        try deleteAll(MediaProductionBeat.self)
        try deleteAll(Item.self)

        try modelContext.save()
        try CabinetFolder.ensureRootFoldersSeeded(modelContext: modelContext)
        try modelContext.save()
    }
}
