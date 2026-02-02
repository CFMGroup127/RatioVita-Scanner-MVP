import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class ReceiptsViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var searchText: String = ""
    @Published var showScanner = false

    // Mutable so dependencies can be updated without replacing the StateObject.
    private(set) var scanner: ScannerService
    private(set) var context: ModelContext

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false

    init(scanner: ScannerService, context: ModelContext) {
        self.scanner = scanner
        self.context = context
    }

    // Update dependencies safely (avoid reassigning the @StateObject in the view).
    func updateDependencies(scanner: ScannerService, context: ModelContext) {
        self.scanner = scanner
        self.context = context
    }

    func scanAndSave() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await scanner.scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)

            let receipt = Receipt(
                merchant: result.extractedData.merchant ?? "Unknown Merchant",
                total: result.extractedData.total ?? 0,
                currencyCode: result.extractedData.currency ?? (Locale.current.currency?.identifier ?? "USD")
            )

            var images: [ReceiptImage] = []
            for (idx, page) in result.scannedPages.enumerated() {
                let img = ReceiptImage(
                    pageIndex: idx,
                    image: page.image,
                    ocrText: page.ocrText,
                    receipt: receipt,
                    compressionQuality: compressionEnabled ? 0.6 : 0.9
                )
                images.append(img)
            }
            receipt.images = images

            context.insert(receipt)
            try context.save()
        } catch {
            print("Scan failed: \(error)")
        }
    }

    func delete(_ receipts: [Receipt]) {
        for r in receipts {
            context.delete(r)
        }
        try? context.save()
    }
    
    // MARK: - Scanner Presentation
    
    func showScannerUI() {
        showScanner = true
    }
    
    func handleScanResult(_ result: ScanResult) async {
        isScanning = true
        defer { 
            isScanning = false
            showScanner = false
        }
        
        do {
            let receipt = Receipt(
                merchant: result.extractedData.merchant ?? "Unknown Merchant",
                total: result.extractedData.total ?? 0,
                currencyCode: result.extractedData.currency ?? (Locale.current.currency?.identifier ?? "USD")
            )

            var images: [ReceiptImage] = []
            for (idx, page) in result.scannedPages.enumerated() {
                let img = ReceiptImage(
                    pageIndex: idx,
                    image: page.image,
                    ocrText: page.ocrText,
                    receipt: receipt,
                    compressionQuality: compressionEnabled ? 0.6 : 0.9
                )
                images.append(img)
            }
            receipt.images = images

            context.insert(receipt)
            try context.save()
        } catch {
            print("Scan result processing failed: \(error)")
        }
    }
}