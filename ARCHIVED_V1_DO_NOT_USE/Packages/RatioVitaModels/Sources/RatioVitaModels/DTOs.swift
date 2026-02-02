import Foundation

// MARK: - Data Transfer Objects (DTOs)

/// Data Transfer Object for Asset entity
public struct AssetDTO: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String
    public var purchaseDate: Date?
    public var purchasePrice: Decimal?
    public var currentValue: Decimal?
    public var category: String
    public var location: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        purchaseDate: Date?,
        purchasePrice: Decimal?,
        currentValue: Decimal?,
        category: String,
        location: String,
        notes: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.currentValue = currentValue
        self.category = category
        self.location = location
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Data Transfer Object for Document entity
public struct DocumentDTO: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var type: String
    public var url: String?
    public var size: Int64?
    public var category: String
    public var tags: [String]
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: String,
        url: String?,
        size: Int64?,
        category: String,
        tags: [String],
        notes: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.size = size
        self.category = category
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Type Aliases for Backward Compatibility

public typealias Document = DocumentDTO
