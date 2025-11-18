import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleSeed {
    struct Options {
        var count: Int = 6
        var randomizeDates: Bool = true
        var randomizeTotals: Bool = true
        var includeNotes: Bool = true
        var ocrEnabled: Bool = true
        var compressionQuality: CGFloat = 0.9
        public init() {}
    }

    static func insertSamples(into context: ModelContext, options: Options = .init()) {
        let merchants = [
            "ACME Market",
            "Coffee Corner",
            "Tech Depot",
            "Fresh Farm Grocery",
            "City Fuel",
            "Bella Pizza",
            "Green Leaf Cafe",
            "Book Nook",
        ]

        let notesPool = [
            "Business lunch with client",
            "Office supplies restock",
            "Team coffee run",
            "Fuel for site visit",
            "Weekly grocery",
            "Promo applied at checkout",
        ]

        let calendar = Calendar.current
        let now = Date()

        for i in 0..<options.count {
            _ = i
            let merchant = merchants.randomElement() ?? "Sample Merchant"
            let base = Decimal(Int.random(in: 10...99))
            let cents = Decimal(Double.random(in: 0..<1))
            let total = options.randomizeTotals ? (base + cents) : Decimal(19.99)

            let dayOffset = Int.random(in: 0...20)
            let createdAt = options.randomizeDates ? (calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now) : now

            let currency = Locale.current.currency?.identifier ?? "USD"
            let notes = options.includeNotes ? notesPool.randomElement() : nil

            let receipt = Receipt(
                createdAt: createdAt,
                merchant: merchant,
                total: total,
                currencyCode: currency,
                notes: notes
            )

            let pageCount = [1, 1, 1, 2].randomElement() ?? 1
            var images: [ReceiptImage] = []

            for page in 0..<pageCount {
                let rv = placeholderReceiptImage(width: 900, height: 1400, title: merchant, page: page + 1)
                let ocrText = options.ocrEnabled ? makeOCRText(merchant: merchant, total: total, date: createdAt, page: page + 1) : nil

                let img = ReceiptImage(
                    pageIndex: page,
                    image: rv,
                    ocrText: ocrText,
                    createdAt: createdAt,
                    receipt: receipt,
                    compressionQuality: options.compressionQuality
                )
                images.append(img)
            }

            receipt.images = images
            context.insert(receipt)
        }

        try? context.save()
    }

    private static func makeOCRText(merchant: String, total: Decimal, date: Date, page: Int) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let dateString = df.string(from: date)

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
        let totalString = nf.string(from: total as NSDecimalNumber) ?? "\(total)"

        return """
        \(merchant.uppercased())
        Date: \(dateString)
        Page: \(page)
        Subtotal: \(totalString)
        Tax: \(nf.string(from: 1.23) ?? "1.23")
        Total: \(totalString)
        Items:
          - Coffee x1 3.50
          - Sandwich x1 7.20
        Thank you!
        """
    }

    private static func placeholderReceiptImage(width: Int, height: Int, title: String, page: Int) -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: UIColor.label,
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
            ]

            NSString(string: title).draw(
                in: CGRect(x: 40, y: 60, width: size.width - 80, height: 80),
                withAttributes: titleAttrs
            )

            NSString(string: "Page \(page)").draw(
                in: CGRect(x: 40, y: 140, width: size.width - 80, height: 40),
                withAttributes: subtitleAttrs
            )

            let lineAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel,
            ]
            for i in 0..<20 {
                NSString(string: "Item \(i + 1)   1 x 3.99     3.99")
                    .draw(in: CGRect(x: 40, y: 220 + i * 28, width: Int(size.width - 80), height: 24), withAttributes: lineAttrs)
            }
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 56, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        NSString(string: title).draw(in: NSRect(x: 40, y: size.height - 140, width: size.width - 80, height: 80), withAttributes: titleAttrs)

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        NSString(string: "Page \(page)").draw(in: NSRect(x: 40, y: size.height - 180, width: size.width - 80, height: 40), withAttributes: subtitleAttrs)

        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        for i in 0..<20 {
            NSString(string: "Item \(i + 1)   1 x 3.99     3.99")
                .draw(in: NSRect(x: 40, y: size.height - 260 - CGFloat(i * 28), width: size.width - 80, height: 24), withAttributes: lineAttrs)
        }

        return image
        #endif
    }
}
