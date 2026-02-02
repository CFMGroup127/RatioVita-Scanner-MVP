import Foundation

/// Email scan settings configuration
public struct EmailScanSettings: Codable {
    public let scanFrequency: TimeInterval
    public let scanFromDate: Date
    public let autoProcessReceipts: Bool
    public let includeAttachments: Bool
    
    public init(scanFrequency: TimeInterval = 3600, scanFromDate: Date = Date(), autoProcessReceipts: Bool = true, includeAttachments: Bool = true) {
        self.scanFrequency = scanFrequency
        self.scanFromDate = scanFromDate
        self.autoProcessReceipts = autoProcessReceipts
        self.includeAttachments = includeAttachments
    }
}

/// Email processing settings
public struct EmailProcessingSettings: Codable {
    public let scanFrequency: TimeInterval
    public let autoProcessReceipts: Bool
    public let includeAttachments: Bool
    public let scanFromDate: Date
    
    public init(scanFrequency: TimeInterval = 3600, autoProcessReceipts: Bool = true, includeAttachments: Bool = true, scanFromDate: Date = Date()) {
        self.scanFrequency = scanFrequency
        self.autoProcessReceipts = autoProcessReceipts
        self.includeAttachments = includeAttachments
        self.scanFromDate = scanFromDate
    }
}

/// Currency enumeration
public enum Currency: String, Codable, CaseIterable {
    case USD = "USD"
    case CAD = "CAD"
    case EUR = "EUR"
    case GBP = "GBP"
    
    public var symbol: String {
        switch self {
        case .USD: return "$"
        case .CAD: return "C$"
        case .EUR: return "€"
        case .GBP: return "£"
        }
    }
    
    public var name: String {
        switch self {
        case .USD: return "US Dollar"
        case .CAD: return "Canadian Dollar"
        case .EUR: return "Euro"
        case .GBP: return "British Pound"
        }
    }
}
