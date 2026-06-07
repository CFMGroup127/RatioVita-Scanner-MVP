import Foundation

/// Header embedded in every `.rvvault` cross-device transport package.
struct RatioVitaArchivePackage: Codable, Sendable, Equatable {
    var formatVersion: Int = 1
    var timestamp: Date
    var deviceIdentifier: String
    var deviceName: String
    var schemaVersion: String
    var receiptCount: Int
    var receiptImageCount: Int
    var appMarketingVersion: String

    static let headerFileName = "archive_header.json"
}
