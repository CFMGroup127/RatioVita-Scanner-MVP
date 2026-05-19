import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleData {
    static var previewContainer: ModelContainer {
        let schema = LibrarySwiftDataSchema.makeSchema()
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let context = container.mainContext

        let r1 = Receipt(
            merchant: "Sample Mart",
            total: AccountingAmountPolarity.canonicalTotal(documentType: .receipt, amount: 19.99),
            currencyCode: "USD"
        )
        let r2 = Receipt(
            merchant: "Coffee Corner",
            total: AccountingAmountPolarity.canonicalTotal(documentType: .receipt, amount: 4.75),
            currencyCode: "USD",
            notes: "Latte + croissant"
        )

        let img = placeholderThumb()
        let i1 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Sample Mart\nTotal 19.99")
        let i2 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Coffee Corner\nTotal 4.75")

        r1.images = [i1]
        r2.images = [i2]

        context.insert(r1)
        context.insert(r2)

        let contact = ProductionContact(
            name: "Alex Rivera",
            companyName: "Northwind Pictures",
            email: "alex@example.com",
            tags: ["Producer", "Client"]
        )
        context.insert(contact)

        return container
    }

    // MARK: - Cross-platform placeholder image

    static func placeholderThumb() -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.secondarySystemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let text = "Thumb"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor.tertiaryLabel,
                .paragraphStyle: paragraph,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
            text.draw(in: rect, withAttributes: attrs)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 400, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let text = "Thumb" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        text.draw(in: rect, withAttributes: attrs)

        return image
        #endif
    }
}
