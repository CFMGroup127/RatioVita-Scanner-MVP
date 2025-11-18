import SwiftData
import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.merchant)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(receipt.createdAt, style: .date)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(receipt.total, format: .currency(code: receipt.currencyCode))
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal)
                
                // Images
                if !receipt.images.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Receipt Images")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(receipt.images.enumerated()), id: \.element.id) { _, image in
                                    VStack {
                                        if let platformImage = image.platformImage {
                                            Image(rvImage: platformImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 400)
                                                .cornerRadius(12)
                                        } else {
                                            placeholderImage()
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 400)
                                                .cornerRadius(12)
                                        }
                                        
                                        if let _ = image.ocrText {
                                            Text("Page \(image.pageIndex + 1)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Notes
                if let notes = receipt.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // OCR Text
                if let firstImage = receipt.images.first, let ocrText = firstImage.ocrText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Text")
                            .font(.headline)
                        Text(ocrText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .background(
                                Group {
                                    #if os(iOS)
                                    Color(.systemGray6)
                                    #else
                                    Color.secondary.opacity(0.1)
                                    #endif
                                }
                            )
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Receipt Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            #endif
        }
        .sheet(isPresented: $showingEditSheet) {
            EditReceiptView(receipt: receipt)
        }
    }
    
    // Return Image explicitly so Image modifiers like .resizable() are available
    private func placeholderImage() -> Image {
        #if canImport(UIKit)
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let text = "Image Unavailable"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.systemGray,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
            text.draw(in: rect, withAttributes: attrs)
        }
        return Image(rvImage: image)
        #elseif canImport(AppKit)
        let size = NSSize(width: 300, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        NSColor.systemGray.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let text = "Image Unavailable" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.systemGray,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        text.draw(in: rect, withAttributes: attrs)
        
        return Image(nsImage: image)
        #endif
    }
}

struct EditReceiptView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    @State private var merchant: String
    @State private var total: String
    @State private var notes: String
    
    init(receipt: Receipt) {
        self.receipt = receipt
        _merchant = State(initialValue: receipt.merchant)
        _total = State(initialValue: receipt.total.formatted(.currency(code: receipt.currencyCode)))
        _notes = State(initialValue: receipt.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Receipt Details") {
                    TextField("Merchant", text: $merchant)
                    TextField("Total", text: $total)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Receipt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
    
    private func saveChanges() {
        receipt.merchant = merchant
        
        // Try to parse a currency-formatted string gracefully
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = receipt.currencyCode
        
        if let number = nf.number(from: total) {
            receipt.total = number.decimalValue
        } else if let plain = Decimal(string: total.filter { "0123456789.,".contains($0) }) {
            receipt.total = plain
        }
        
        receipt.notes = notes.isEmpty ? nil : notes
    }
}
