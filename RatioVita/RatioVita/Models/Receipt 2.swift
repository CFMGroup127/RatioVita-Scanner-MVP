import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var merchant: String
    var total: Decimal
    var currencyCode: String
    var notes: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ReceiptImage.receipt) var images: [ReceiptImage]
    
    // MARK: - Computed Properties
    
    /// Cached first image for performance in list views
    var firstImage: RVImage? {
        images.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.platformImage
    }
    
    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        merchant: String,
        total: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        notes: String? = nil,
        images: [ReceiptImage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.merchant = merchant
        self.total = total
        self.currencyCode = currencyCode
        self.notes = notes
        self.images = images
    }
}
