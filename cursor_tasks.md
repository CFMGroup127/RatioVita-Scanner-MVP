## Tasks for Cursor

This document is for delegating specific coding tasks and project analysis to Cursor. Please add all requests for Cursor below this line, along with any necessary context or file paths. Once tasks are complete, please document a detailed summary here as well.

Thank you.


Task 2: Implement RealScannerService (AVFoundation + Vision) - Single Page MVP
Context
• Replace PreviewScannerService with a production implementation for iOS (and macOS if feasible).
• Integrate with existing ScannerService protocol and ReceiptsViewModel.scanAndSave().
• Must work on device and simulator (simulator may use static image fallback).

Requirements
• Create Services/RealScannerService.swift implementing ScannerService.
• Provide a SwiftUI capture flow:
   • Views/Scanner/CameraCaptureView.swift (UIViewControllerRepresentable/NSViewControllerRepresentable).
   • Views/Scanner/ScannerCoordinator.swift (AVCapturePhotoCaptureDelegate bridge).
• Capture a single still image (AVCapturePhotoOutput).
• Run VNRecognizeTextRequest with OCR toggle support (fast vs accurate).
• Return ScanResult with one ScannedPage (image + OCR text).
• Handle camera permission and error states gracefully.

Acceptance Criteria
• Tapping Scan opens camera, captures one page, performs OCR (if enabled), inserts a Receipt with one ReceiptImage, and returns to list.
• Works on iOS device; simulator uses a bundled placeholder image.
• Code compiles on macOS target; if capture is not implemented on macOS yet, provide a clear fallback.

Deliverables
• Services/RealScannerService.swift
• Views/Scanner/CameraCaptureView.swift
• Views/Scanner/ScannerCoordinator.swift
• Updated ReceiptsViewModel to present/dismiss capture UI and call RealScannerService.

Task 3: Image Processing Helpers (Perspective, Denoise, Compression)
Context
• Improve captured image quality before OCR and storage.

Requirements
• Create Utilities/ImageProcessing.swift.
• Implement functions:
   • correctPerspective(image: UIImage/NSImage, quad: optional) -> UIImage/NSImage
   • denoiseAndEnhance(image:) -> UIImage/NSImage
   • compressedData(from:image, quality: config) -> Data
• Use Core Image filters (CIPerspectiveCorrection, CINoiseReduction, CIColorControls).
• Wire compression toggle to affect JPEG quality (e.g., 0.9 off, 0.6 on).

Acceptance Criteria
• Unit-testable pure functions where possible.
• Integrated into RealScannerService pipeline with feature flags.

Deliverables
• Utilities/ImageProcessing.swift
• Minimal tests (optional now, planned in Task 6).

Task 4: OCR Parsing Utilities (Merchant, Date, Total)
Context
• Extract basic structured fields from OCR text.

Requirements
• Create Utilities/OCRParsing.swift.
• Implement functions:
   • parseMerchant(from:) -> String?
   • parseDate(from:) -> Date?
   • parseTotal(from:) -> Decimal?
• Use lightweight regex/heuristics; include basic locale support for date/decimal.

Acceptance Criteria
• Functions return best-effort values with nil on failure.
• Wire into RealScannerService to populate ScanResult.

Deliverables
• Utilities/OCRParsing.swift
• Minimal tests (optional now, planned in Task 6).

Task 5: Multi-Page Capture Flow
Context
• Extend capture flow to support multiple pages.

Requirements
• Update CameraCaptureView to allow Add Page / Retake / Done.
• Accumulate pages and return an array of ScannedPage.
• Present a simple review UI before saving.

Acceptance Criteria
• User can capture 1..N pages, review thumbnails, and save.
• Receipts save with multiple ReceiptImage records in page order.

Deliverables
• Updated Views/Scanner/* and RealScannerService.

Task 6: Tests and Documentation
Context
• Ensure stability and future maintainability.

Requirements
• Add Swift Testing or XCTest for OCRParsing and ImageProcessing.
• Add Docs/ScannerPipelinePlan.md (updated from Task 1) with implementation details and decisions.
• Add inline documentation/comments and a brief README for the Scanner module.

Acceptance Criteria
• Tests pass locally.
• Docs updated and accurate.

Deliverables
• Tests (Testing/ or Tests/)
• Docs/ScannerPipelinePlan.md (updated)
• README/inline docs




Tasks for Cursor

This document is for delegating specific coding tasks and project analysis to Cursor. Please add all requests for Cursor below this line, along with any necessary context or file paths. Once tasks are complete, please document a detailed summary here as well.

Thank you.

Task 2: Implement RealScannerService (AVFoundation + Vision) - Single Page MVP
Format
• Provide code as full file contents (not diffs) for each file listed below.
• Confirm final file paths and target membership in cursor_report.md􀰓.
• Include build/run verification notes and any Info.plist additions.

Scope and actions
• Create Services/RealScannerService.swift implementing ScannerService.
• Provide a SwiftUI capture flow:
   • Views/Scanner/CameraCaptureView.swift (UIViewControllerRepresentable for iOS; NSViewControllerRepresentable for macOS if implemented).
   • Views/Scanner/ScannerCoordinator.swift (AVCapturePhotoCaptureDelegate bridge).
• Capture a single still image (AVCapturePhotoOutput).
• Run VNRecognizeTextRequest with OCR toggle support (fast vs accurate).
• Return ScanResult with one ScannedPage (image + OCR text).
• Handle camera permission and error states gracefully.

Verification
• On iOS device: tapping Scan opens camera, captures one page, performs OCR (if enabled), inserts a Receipt with one ReceiptImage, and returns to list.
• On iOS simulator: use a static image fallback.
• On macOS: project compiles; if camera capture isn’t implemented yet, use mock fallback and document behavior.

Deliverables
• Services/RealScannerService.swift
• Views/Scanner/CameraCaptureView.swift
• Views/Scanner/ScannerCoordinator.swift
• Updates to ViewModels/ReceiptsViewModel.swift and Views/ReceiptsView.swift to present/dismiss capture UI and call RealScannerService.
• cursor_report.md􀰓 updated under “Task 2” with steps, file paths, and verification results.

Task 3: Image Processing Helpers (Perspective, Denoise, Compression)
Format
• Provide a new Utilities/ImageProcessing.swift with documented, unit-testable functions.
• Add example usage and before/after notes to cursor_report.md􀰓.

Scope and actions
• Implement:
   • correctPerspective(image:quad:) -> UIImage/NSImage
   • denoiseAndEnhance(image:) -> UIImage/NSImage
   • compressedData(from:quality:) -> Data
• Use Core Image filters: CIPerspectiveCorrection, CINoiseReduction, CISharpenLuminance, CIColorControls.
• Wire compression toggle: on = 0.6 JPEG quality, off = 0.9.

Verification
• Functions compile and can be called from RealScannerService.
• cursor_report.md􀰓 includes example outputs and notes.

Deliverables
• Utilities/ImageProcessing.swift
• cursor_report.md􀰓 updated under “Task 3”

Task 4: OCR Parsing Utilities (Merchant, Date, Total)
Format
• Provide a new Utilities/OCRParsing.swift with unit-testable functions.
• Include example inputs/outputs and brief parsing rationale in cursor_report.md􀰓.

Scope and actions
• Implement:
   • parseMerchant(from:) -> String?
   • parseDate(from:) -> Date?
   • parseTotal(from:) -> Decimal?
• Use regex + locale-aware parsing; return nil on failure with simple confidence hints.

Verification
• Functions return reasonable values on sample OCR text (e.g., ACME Market, dates, totals).
• cursor_report.md􀰓 includes example runs.

Deliverables
• Utilities/OCRParsing.swift
• cursor_report.md􀰓 updated under “Task 4”

Task 5: Multi-Page Capture Flow
Format
• Provide full-file updates for RealScannerService and new/updated scanner views.
• Document UI flow and state handling in cursor_report.md􀰓.

Scope and actions
• Extend capture flow to support multiple pages:
   • Add Add Page / Retake / Done.
   • Accumulate ScannedPage array.
   • Present a simple review UI before saving.
• Save multiple ReceiptImage entries in pageIndex order.

Verification
• Capture 1..N pages, review thumbnails, save receipt with N images.
• cursor_report.md􀰓 includes test notes and screenshots or descriptive steps.

Deliverables
• Updated Services/RealScannerService.swift
• Updated Views/Scanner/* (CameraCaptureView, ScannerCoordinator, plus any review UI)
• cursor_report.md􀰓 updated under “Task 5”

Task 6: Tests and Documentation
Format
• Use Swift Testing (preferred) or XCTest.
• Place tests under Tests/ or Testing/.
• Document test results and commands in cursor_report.md􀰓.

Scope and actions
• Add tests:
   • OCRParsingTests: merchant/date/total extraction.
   • ImageProcessingTests: compression reduces size and maintains reasonable quality.
• Update Docs/ScannerPipelinePlan.md with implementation decisions and any deviations.
• Add inline documentation and a short README for the Scanner module.

Verification
• Tests compile and pass locally.
• cursor_report.md􀰓 includes test summaries.

Deliverables
• Tests/OCRParsingTests.swift
• Tests/ImageProcessingTests.swift
• Updated Docs/ScannerPipelinePlan.md
• README/inline docs for Scanner module
• cursor_report.md􀰓 updated under “Task 6”

Task 7: Verify Receipts-first Files and Fix Build Errors
Format
• Provide a checklist in cursor_report.md􀰓 with:
   • Confirmed file paths (absolute and project-relative)
   • Target membership confirmation (text description of Xcode steps)
   • Build output summary (success/fail) and any warnings
• Provide a short diff summary (file names only) if files were moved/added.

Scope and actions
• Verify these files exist and are part of the RatioVita app target:
   • Models/Receipt.swift
   • Models/ReceiptImage.swift
   • Utilities/SampleData.swift
   • Views/ReceiptsView.swift
• Verify RatioVitaApp.swift􀰓 includes Receipt and ReceiptImage in the SwiftData schema.
• If missing or outside the project, add/move them under the correct groups and target.

Verification
• Xcode builds successfully; no “Cannot find ‘…’ in scope” errors.
• ContentView previews load using SampleData.previewContainer.

Deliverables
• cursor_report.md􀰓 updated with Task 7 verification.

Task 8: Project Configuration and Simulator Matrix
Format
• Create Docs/Config.md documenting:
   • Platform targets and minimum OS versions
   • Required Info.plist keys
   • Capabilities to enable
   • Recommended simulator list
   • How to switch between PreviewScannerService and RealScannerService

Scope and actions
• Add iOS Info.plist entries (if not present):
   • NSCameraUsageDescription
   • NSPhotoLibraryUsageDescription
   • NSPhotoLibraryAddUsageDescription
• Add/confirm Camera capability in iOS target.
• Document recommended simulators:
   • iPhone 15 Pro Max, iPhone 15/16, iPad 10th Gen 11", iPad Pro 13"
• Document macOS target run behavior and camera fallback if not implemented yet.
• Define runtime/build-time selection strategy for scanner service.

Verification
• Docs/Config.md exists and is accurate.
• App builds for iOS and macOS after any Info.plist/capability changes.
• cursor_report.md􀰓 logs completion.

Deliverables
• Docs/Config.md
• cursor_report.md􀰓 updated under “Task 8”

Task 9: Integrate RealScannerService behind a runtime switch
Format
• Provide full-file contents for changes to:
   • Services/RealScannerService.swift (if not already present)
   • Views/ReceiptsView.swift (service selection)
   • ViewModels/ReceiptsViewModel.swift (DI setup)
• Confirm file locations and target membership in cursor_report.md􀰓.

Scope and actions
• Runtime switch:
   • If running on iOS device and camera permission is authorized → use RealScannerService
   • Else → use PreviewScannerService
• Ensure SwiftUI previews always use PreviewScannerService.

Verification
• iOS device: Scan opens camera, OCR runs, receipt saved.
• iOS simulator: Scan uses mock path and saves a sample receipt.
• macOS: compiles; fallback documented if camera unimplemented.

Deliverables
• Updated code files listed above.
• cursor_report.md􀰓 updated under “Task 9” with test steps and results.

Task 10: Minimal tests for OCRParsing and ImageProcessing
Format
• Use Swift Testing or XCTest.
• Place tests in Tests/ or Testing/.

Scope and actions
• Add tests:
   • OCRParsingTests for merchant/date/total on sample OCR text.
   • ImageProcessingTests verifying compression produces smaller data at lower quality settings.
• Document test runs and results in cursor_report.md􀰓.

Verification
• Tests compile and pass locally.

Deliverables
• Tests/OCRParsingTests.swift
• Tests/ImageProcessingTests.swift
• cursor_report.md􀰓 updated under “Task 10”

END OF PASTE FOR TASKS

COPY FROM HERE (add missing Swift files to your project)

Note: Add each file to the RatioVita app target. Create folders/groups to match paths.

Swift file: RatioVitaApp.swift􀰓
//
//  RatioVitaApp.swift􀰓
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftUI
import SwiftData

@main
struct RatioVitaApp: App {
var sharedModelContainer: ModelContainer = {

    let schema = Schema([

        Item.self,

        Receipt.self,

        ReceiptImage.self

    ])

    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)


    do {

        return try ModelContainer(for: schema, configurations: [modelConfiguration])

    } catch {

        fatalError("Could not create ModelContainer: \(error)")

    }

}()


var body: some Scene {

    WindowGroup {

        ContentView()

    }

    .modelContainer(sharedModelContainer)

}

}

Swift file: ContentView.swift􀰓
//
//  ContentView.swift􀰓
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftUI
import SwiftData

struct ContentView: View {
@Environment(\.modelContext) private var modelContext


var body: some View {

    #if os(macOS)

    NavigationSplitView {

        ReceiptsView()

    } detail: {

        Text("Select a receipt")

    }

    .navigationTitle("Receipts")

    #else

    NavigationStack {

        ReceiptsView()

            .navigationTitle("Receipts")

    }

    #endif

}

}

#Preview {
ContentView()

    .modelContainer(SampleData.previewContainer)

}

Swift file: Models/Receipt.swift
import Foundation
import SwiftData

@Model
final class Receipt {
@Attribute(.unique) var id: UUID

var createdAt: Date

var merchant: String

var total: Decimal

var currencyCode: String

var notes: String?

@Relationship(deleteRule: .cascade, inverse: \ReceiptImage.receipt) var images: [ReceiptImage]


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

Swift file: Models/ReceiptImage.swift
import Foundation
import SwiftData
import SwiftUI

@Model
final class ReceiptImage {
@Attribute(.unique) var id: UUID

var pageIndex: Int

var ocrText: String?

var createdAt: Date

var imageData: Data


@Relationship var receipt: Receipt?


init(

    id: UUID = UUID(),

    pageIndex: Int,

    image: UIImage,

    ocrText: String? = nil,

    createdAt: Date = .now,

    receipt: Receipt? = nil

) {

    self.id = id

    self.pageIndex = pageIndex

    self.ocrText = ocrText

    self.createdAt = createdAt

    self.imageData = image.jpegData(compressionQuality: 0.9) ?? Data()

    self.receipt = receipt

}


var uiImage: UIImage? {

    UIImage(data: imageData)

}

}

Swift file: Services/ScannerService.swift
import Foundation
import SwiftUI

struct ScanResult {
let merchant: String

let total: Decimal

let currencyCode: String

let pages: [ScannedPage]

}

struct ScannedPage {
let image: UIImage

let ocrText: String?

}

protocol ScannerService {
func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult

}

Swift file: Services/PreviewScannerService.swift
import Foundation
import SwiftUI

enum PreviewScannerError: Error {
case failed

}

final class PreviewScannerService: ScannerService {
func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {

    try await Task.sleep(nanoseconds: 300_000_000)


    let demoImage = Self.placeholderImage()

    let ocr = ocrEnabled ? "ACME MARKET\nDate: \(Date())\nTotal: 42.39\nItems: Apples, Bread, Milk" : nil


    let page = ScannedPage(image: demoImage, ocrText: ocr)

    return ScanResult(

        merchant: "ACME Market",

        total: Decimal(string: "42.39") ?? 42.39,

        currencyCode: Locale.current.currency?.identifier ?? "USD",

        pages: [page]

    )

}


private static func placeholderImage(size: CGSize = CGSize(width: 800, height: 1200)) -> UIImage {

    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { ctx in

        UIColor.systemBackground.setFill()

        ctx.fill(CGRect(origin: .zero, size: size))


        let text = "Receipt Preview"

        let paragraph = NSMutableParagraphStyle()

        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [

            .font: UIFont.systemFont(ofSize: 48, weight: .bold),

            .foregroundColor: UIColor.secondaryLabel,

            .paragraphStyle: paragraph

        ]

        let rect = CGRect(x: 0, y: size.height/2 - 30, width: size.width, height: 60)

        text.draw(in: rect, withAttributes: attrs)

    }

}

}

Swift file: ViewModels/ReceiptsViewModel.swift
import Foundation
import SwiftUI
import SwiftData

@MainActor
final class ReceiptsViewModel: ObservableObject {
@Published var isScanning = false

@Published var searchText: String = ""


private let scanner: ScannerService

private let context: ModelContext


@AppStorage("settings.ocrEnabled") private var ocrEnabled: Bool = true

@AppStorage("settings.compressionEnabled") private var compressionEnabled: Bool = false


init(scanner: ScannerService, context: ModelContext) {

    self.scanner = scanner

    self.context = context

}


func scanAndSave() async {

    isScanning = true

    defer { isScanning = false }


    do {

        let result = try await scanner.scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)


        let receipt = Receipt(

            merchant: result.merchant,

            total: result.total,

            currencyCode: result.currencyCode

        )


        var images: [ReceiptImage] = []

        for (idx, page) in result.pages.enumerated() {

            let img = ReceiptImage(pageIndex: idx, image: page.image, ocrText: page.ocrText, receipt: receipt)

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

}

Swift file: Utilities/SampleData.swift
import Foundation
import SwiftData
import SwiftUI

enum SampleData {
static var previewContainer: ModelContainer {

    let schema = Schema([

        Item.self,

        Receipt.self,

        ReceiptImage.self

    ])

    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

    let container = try! ModelContainer(for: schema, configurations: [config])


    let context = container.mainContext


    let r1 = Receipt(merchant: "Sample Mart", total: 19.99, currencyCode: "USD")

    let r2 = Receipt(merchant: "Coffee Corner", total: 4.75, currencyCode: "USD", notes: "Latte + croissant")


    let img = placeholderThumb()

    let i1 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Sample Mart\nTotal 19.99", receipt: r1)

    let i2 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Coffee Corner\nTotal 4.75", receipt: r2)

    r1.images = [i1]

    r2.images = [i2]


    context.insert(r1)

    context.insert(r2)


    return container

}


private static func placeholderThumb() -> UIImage {

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

            .paragraphStyle: paragraph

        ]

        let rect = CGRect(x: 0, y: size.height/2 - 20, width: size.width, height: 40)

        text.draw(in: rect, withAttributes: attrs)

    }

}

}

Swift file: Views/ReceiptsView.swift
import SwiftUI
import SwiftData

struct ReceiptsView: View {
@Environment(\.modelContext) private var modelContext


@Query(sort: \Receipt.createdAt, order: .reverse, animation: .default)

private var receipts: [Receipt]


@StateObject private var viewModel: ReceiptsViewModel


@AppStorage("settings.ocrEnabled") private var ocrEnabled: Bool = true

@AppStorage("settings.compressionEnabled") private var compressionEnabled: Bool = false


@State private var searchText: String = ""


init() {

    let schema = Schema([Item.self, Receipt.self, ReceiptImage.self])

    let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])

    _viewModel = StateObject(wrappedValue: ReceiptsViewModel(scanner: PreviewScannerService(), context: ModelContext(container)))

}


var body: some View {

    let filtered = filteredReceipts()


    VStack {

        List {

            ForEach(filtered) { receipt in

                NavigationLink {

                    ReceiptDetailView(receipt: receipt)

                } label: {

                    HStack(spacing: 12) {

                        if let ui = receipt.images.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.uiImage {

                            Image(uiImage: ui)

                                .resizable()

                                .scaledToFill()

                                .frame(width: 44, height: 60)

                                .clipped()

                                .cornerRadius(6)

                        } else {

                            RoundedRectangle(cornerRadius: 6)

                                .fill(Color.secondary.opacity(0.2))

                                .frame(width: 44, height: 60)

                        }

                        VStack(alignment: .leading) {

                            Text(receipt.merchant)

                                .font(.headline)

                            Text(receipt.createdAt, style: .date)

                                .font(.subheadline)

                                .foregroundStyle(.secondary)

                        }

                        Spacer()

                        Text(formattedTotal(receipt))

                            .font(.headline)

                    }

                    .padding(.vertical, 4)

                }

            }

            .onDelete(perform: delete)

        }

        .searchable(text: $searchText, placement: .automatic)

        .overlay {

            if receipts.isEmpty {

                ContentUnavailableView("No Receipts", systemImage: "doc.text.image", description: Text("Tap Scan to add your first receipt."))

            }

        }

        .toolbar {

            ToolbarItemGroup(placement: .navigationBarTrailing) {

                NavigationLink {

                    SettingsView()

                } label: {

                    Image(systemName: "gearshape")

                }

                ScanButton(isScanning: viewModel.isScanning) {

                    await viewModel.scanAndSave()

                }

            }

        }

    }

    .onAppear {

        let newVM = ReceiptsViewModel(scanner: PreviewScannerService(), context: modelContext)

        _viewModel.wrappedValue = newVM

    }

}


private func delete(at offsets: IndexSet) {

    let toDelete = offsets.map { filteredReceipts()[$0] }

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

    let nf = NumberFormatter()

    nf.numberStyle = .currency

    nf.currencyCode = receipt.currencyCode

    return nf.string(from: receipt.total as NSDecimalNumber) ?? "\(receipt.total)"

}

}

#Preview("ReceiptsView") {
NavigationStack {

    ReceiptsView()

}

.modelContainer(SampleData.previewContainer)

}

Swift file: Views/ReceiptDetailView.swift
import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
@Environment(\.modelContext) private var modelContext


@State var receipt: Receipt


var body: some View {

    Form {

        Section("Info") {

            TextField("Merchant", text: $receipt.merchant)

            TextField("Notes", text: Binding($receipt.notes, replacingNilWith: ""))

            HStack {

                Text("Date")

                Spacer()

                DatePicker("", selection: $receipt.createdAt, displayedComponents: [.date, .hourAndMinute])

                    .labelsHidden()

            }

            HStack {

                Text("Total")

                Spacer()

                Text(formattedTotal(receipt))

                    .foregroundStyle(.secondary)

            }

        }


        Section("Pages") {

            if receipt.images.isEmpty {

                Text("No pages").foregroundStyle(.secondary)

            } else {

                ScrollView(.horizontal, showsIndicators: false) {

                    HStack(spacing: 12) {

                        ForEach(receipt.images.sorted(by: { $0.pageIndex < $1.pageIndex })) { img in

                            VStack(alignment: .leading) {

                                if let ui = img.uiImage {

                                    Image(uiImage: ui)

                                        .resizable()

                                        .scaledToFit()

                                        .frame(width: 140, height: 200)

                                        .cornerRadius(8)

                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                                } else {

                                    RoundedRectangle(cornerRadius: 8)

                                        .fill(Color.secondary.opacity(0.2))

                                        .frame(width: 140, height: 200)

                                }

                                if let text = img.ocrText, !text.isEmpty {

                                    Text(text)

                                        .font(.caption)

                                        .foregroundStyle(.secondary)

                                        .lineLimit(4)

                                }

                            }

                        }

                    }

                    .padding(.vertical, 8)

                }

            }

        }

    }

    .navigationTitle(receipt.merchant)

    .navigationBarTitleDisplayMode(.inline)

    .onDisappear {

        try? modelContext.save()

    }

}


private func formattedTotal(_ receipt: Receipt) -> String {

    let nf = NumberFormatter()

    nf.numberStyle = .currency

    nf.currencyCode = receipt.currencyCode

    return nf.string(from: receipt.total as NSDecimalNumber) ?? "\(receipt.total)"

}

}

private extension Binding where Value == String? {
init(_ source: Binding<String?>, replacingNilWith replacement: String) {

    self.init(

        get: { source.wrappedValue ?? replacement },

        set: { source.wrappedValue = $0 }

    )

}

}

#Preview("ReceiptDetailView") {
let container = SampleData.previewContainer

let context = container.mainContext


let fetch = FetchDescriptor<Receipt>()

let receipts = try? context.fetch(fetch)

let sample = receipts?.first ?? Receipt(merchant: "Sample", total: 1.23)


return NavigationStack {

    ReceiptDetailView(receipt: sample)

}

.modelContainer(container)

}

Swift file: Views/ScanButton.swift
import SwiftUI

struct ScanButton: View {
var isScanning: Bool

var action: () async -> Void


var body: some View {

    Button {

        Task { await action() }

    } label: {

        if isScanning {

            ProgressView()

        } else {

            Label("Scan", systemImage: "camera.viewfinder")

        }

    }

    .disabled(isScanning)

}

}

Swift file: Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
@AppStorage("settings.ocrEnabled") private var ocrEnabled: Bool = true

@AppStorage("settings.compressionEnabled") private var compressionEnabled: Bool = false


var body: some View {

    Form {

        Section("Scanner") {

            Toggle("Enable OCR", isOn: $ocrEnabled)

            Toggle("Enable Compression", isOn: $compressionEnabled)

        }


        Section("About") {

            Text("RatioVita")

            Text("Receipts-first preview build")

                .foregroundStyle(.secondary)

        }

    }

    .navigationTitle("Settings")

}

}

#Preview {
NavigationStack {

    SettingsView()

}

}


