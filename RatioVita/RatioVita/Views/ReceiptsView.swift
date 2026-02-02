import SwiftUI
import SwiftData

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Receipt.createdAt, order: .reverse, animation: .default)
    private var receipts: [Receipt]

    @StateObject private var viewModel: ReceiptsViewModel

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false

    @State private var searchText: String = ""

    init() {
        // Create a temporary in-memory context only to satisfy @StateObject initialization.
        // We will update the dependencies safely in .onAppear without reassigning the StateObject.
        let schema = Schema([Item.self, Receipt.self, ReceiptImage.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        _viewModel = StateObject(wrappedValue: ReceiptsViewModel(scanner: PreviewScannerService(), context: ModelContext(container)))
    }

    var body: some View {
        let filtered = filteredReceipts()

        VStack(spacing: 0) {
            // Enhanced header with 144.0 px Sovereign Ceiling (Monday Ignition)
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    SectionHeader(
                        title: "Receipts",
                        subtitle: "\(filtered.count) receipt\(filtered.count == 1 ? "" : "s")"
                    )
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .frame(minHeight: DesignSystem.Layout.sovereignHeaderHeight)
            .background(Color.ratioVitaAdaptiveBackground)
            
            // Enhanced list with new design system
            List {
                ForEach(filtered) { receipt in
                    NavigationLink {
                        ReceiptDetailView(receipt: receipt)
                    } label: {
                        ReceiptRowView(receipt: receipt)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.xs,
                        leading: DesignSystem.Spacing.md,
                        bottom: DesignSystem.Spacing.xs,
                        trailing: DesignSystem.Spacing.md
                    ))
                }
                .onDelete { offsets in
                    delete(at: offsets, from: filtered)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.ratioVitaAdaptiveBackground)
            .searchable(text: $searchText, placement: .automatic)
            .overlay {
                if receipts.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 64))
                            .foregroundColor(Color.ratioVitaTextSecondary)
                        
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("No Receipts")
                                .font(DesignSystem.Typography.title2)
                                .foregroundColor(Color.ratioVitaAdaptiveText)
                            
                            Text("Tap Scan to add your first receipt.")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.ratioVitaTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(DesignSystem.Spacing.xl)
                }
            }
            .toolbar {
                // Settings + Scan
                #if os(iOS)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    ScanButton(isScanning: viewModel.isScanning) {
                        viewModel.showScannerUI()
                    }
                }
                #else
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    ScanButton(isScanning: viewModel.isScanning) {
                        viewModel.showScannerUI()
                    }
                }
                #endif

                // Seed button (DEBUG only), platform-appropriate placement
                #if DEBUG
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        SampleSeed.insertSamples(into: modelContext)
                    } label: {
                        Label("Seed", systemImage: "tray.and.arrow.down.fill")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        SampleSeed.insertSamples(into: modelContext)
                    } label: {
                        Label("Seed", systemImage: "tray.and.arrow.down.fill")
                    }
                }
                #endif
                #endif
            }
        }
        .onAppear {
            // IMPORTANT: Do NOT reassign the @StateObject.
            // Update its dependencies instead so we avoid "invalid reuse after initialization failure".
            #if os(iOS)
            #if targetEnvironment(simulator)
            let scanner: ScannerService = PreviewScannerService()
            #else
            let scanner: ScannerService = RealScannerService()
            #endif
            #else
            let scanner: ScannerService = PreviewScannerService()
            #endif

            viewModel.updateDependencies(scanner: scanner, context: modelContext)
        }
        .sheet(isPresented: $viewModel.showScanner) {
            #if os(iOS)
            CameraCaptureView { scanResult in
                // Wrap in Task so this compiles whether the closure is sync or async.
                Task {
                    await viewModel.handleScanResult(scanResult)
                }
            }
            #else
            ScannerView()
            #endif
        }
    }

    private func delete(at offsets: IndexSet, from filtered: [Receipt]) {
        let toDelete = offsets.map { filtered[$0] }
        viewModel.delete(toDelete)
    }

    private func filteredReceipts() -> [Receipt] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return receipts
        }
        let term = searchText.lowercased()
        return receipts.filter { r in
            if r.merchant.lowercased().contains(term) { return true }
            if r.notes?.lowercased().contains(term) == true { return true }
            if r.images.contains(where: { ($0.ocrText?.lowercased().contains(term) ?? false) }) { return true }
            return false
        }
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let formatter = CurrencyFormatter.shared
        return formatter.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

// MARK: - Receipt Row View

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Receipt thumbnail
            Group {
                if let firstImage = receipt.firstImage {
                    Image(rvImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 80)
                        .clipped()
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(Color.ratioVitaBorder)
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "doc.text.image")
                                .font(.title2)
                                .foregroundColor(Color.ratioVitaTextSecondary)
                        )
                }
            }
            .shadow(DesignSystem.Shadow.small)
            
            // Receipt details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaAdaptiveText)
                    .lineLimit(1)
                
                Text(receipt.createdAt, style: .date)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(Color.ratioVitaTextSecondary)
                
                if let notes = receipt.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(Color.ratioVitaTextSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status badges
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if receipt.images.count > 1 {
                        StatusBadge.info("\(receipt.images.count) pages")
                    }
                    
                    // Show OCR badge if any image has OCR text
                    if receipt.images.contains(where: { $0.ocrText?.isEmpty == false }) {
                        StatusBadge.success("OCR")
                    }
                }
            }
            
            Spacer()
            
            // Total amount
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text(formattedTotal(receipt))
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaPrimary)
                    .fontWeight(.semibold)
                
                Text(receipt.currencyCode)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(Color.ratioVitaTextSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(
            backgroundColor: Color.ratioVitaAdaptiveSurface,
            cornerRadius: DesignSystem.CornerRadius.md,
            shadow: DesignSystem.Shadow.small
        )
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let formatter = CurrencyFormatter.shared
        return formatter.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

#Preview("ReceiptsView") {
    NavigationStack {
        ReceiptsView()
    }
    .modelContainer(SampleData.previewContainer)
}
