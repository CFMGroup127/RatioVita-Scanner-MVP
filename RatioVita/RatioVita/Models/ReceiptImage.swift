import Foundation
import SwiftData
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class ReceiptImage {
    @Attribute(.unique) var id: UUID
    var pageIndex: Int
    var ocrText: String?
    var createdAt: Date
    
    // Stored as JPEG-encoded data for portability across platforms
    var imageData: Data
    
    // Parent relationship
    @Relationship var receipt: Receipt?
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        pageIndex: Int,
        image: RVImage,
        ocrText: String? = nil,
        createdAt: Date = .now,
        receipt: Receipt? = nil,
        compressionQuality: CGFloat = 0.9
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.ocrText = ocrText
        self.createdAt = createdAt
        imageData = ReceiptImage.encodeJPEG(image: image, quality: compressionQuality)
        self.receipt = receipt
    }
    
    // MARK: - Platform helpers
    
    var platformImage: RVImage? {
        ReceiptImage.decodeImage(from: imageData)
    }
    
    // MARK: - Encoding/Decoding
    
    private static func encodeJPEG(image: RVImage, quality: CGFloat) -> Data {
        #if canImport(UIKit)
        return image.jpegData(compressionQuality: quality) ?? Data()
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else
        {
            return Data()
        }
        return jpeg
        #endif
    }
    
    private static func decodeImage(from data: Data) -> RVImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
    }
}
