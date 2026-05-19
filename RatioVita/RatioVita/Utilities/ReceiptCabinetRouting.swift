import Foundation

/// Maps tax / merchant hints to `DocumentCabinet.rawValue` for post-review filing (`Receipt.filingCabinetKindRaw`).
enum ReceiptCabinetRouting {
    /// When the user picks **Fuel**, always file under **Vehicles** for forensic vehicle expense grouping.
    @MainActor
    static func applyImplicitCabinetForDocumentType(receipt: Receipt) {
        let dt = DocumentTypeOption.fromStored(receipt.documentType)
        if dt == .fuel {
            receipt.filingCabinetKindRaw = DocumentCabinet.vehicles.rawValue
        }
    }

    static func suggestedCabinetKindRaw(taxCategory: String?, merchant: String?, productionType: String?) -> String? {
        if merchantSuggestsCanadianFuelOrConvenience(merchant) {
            return DocumentCabinet.vehicles.rawValue
        }

        let corpus = [taxCategory, merchant, productionType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        guard !corpus.isEmpty else { return nil }

        let vehicleHints = [
            "vehicle",
            "fuel",
            "gas ",
            "parking",
            "auto",
            "tire",
            "uber",
            "lyft",
            "mileage",
            "car ",
            "truck",
        ]
        let equipmentHints = [
            "equipment", "rental", "camera", "grip", "electric", "generator", "lighting", "dolly", "mcquade",
        ]
        let toolsHints = ["tool", "hardware", "drill", "saw", "ladder", "fastener"]

        if vehicleHints.contains(where: { corpus.contains($0) }) { return DocumentCabinet.vehicles.rawValue }
        if equipmentHints.contains(where: { corpus.contains($0) }) { return DocumentCabinet.equipment.rawValue }
        if toolsHints.contains(where: { corpus.contains($0) }) { return DocumentCabinet.tools.rawValue }
        return nil
    }

    /// Canadian (and common chain) fuel / highway retail where the **merchant** line is the strongest signal.
    private static func merchantSuggestsCanadianFuelOrConvenience(_ merchant: String?) -> Bool {
        guard let raw = merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return false }
        let m = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()

        if m.range(of: #"(^|[^a-z0-9])shell([^a-z0-9]|$)"#, options: .regularExpression) != nil {
            return true
        }

        // ExxonMobil / Mobil fuel — whole word only (avoid matching “mobile” phone bills).
        if m.range(of: #"(^|[^a-z0-9])mobil([^a-z0-9]|$)"#, options: .regularExpression) != nil {
            return true
        }

        let chainTokens = [
            "petro-canada",
            "petro canada",
            "petrocanada",
            "esso",
            "ultramar",
            "pioneer",
            "husky",
            "sunoco",
            "irving",
            "couche-tard",
            "mac's",
            "circle k",
        ]
        return chainTokens.contains(where: { m.contains($0) })
    }
}
