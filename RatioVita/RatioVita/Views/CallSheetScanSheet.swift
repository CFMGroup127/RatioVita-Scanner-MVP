import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

/// Home-dashboard **call sheet sniper**: OCR page 1, then pre-fills Labor Sentinel for the matching calendar day.
struct CallSheetScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryNavigationCoordinator.self) private var libraryNavigationCoordinator

    @AppStorage("ocrEnabled") private var ocrEnabled = true
    @AppStorage("compressionEnabled") private var compressionEnabled = false

    #if canImport(PhotosUI)
    @State private var pickerItem: PhotosPickerItem?
    #endif
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Photograph **page 1** of the call sheet. We OCR the header for **CREW CALL** (e.g. 1400) "
                            + "and **Location 1**, then jump to Labor Sentinel — open the matching **work day** to apply."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                #if canImport(PhotosUI)
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label("Choose call sheet photo", systemImage: "doc.viewfinder")
                    }
                    .disabled(isBusy)
                }
                #endif
                if isBusy {
                    Section {
                        ProgressView("Reading header…")
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.ratioVitaError)
                    }
                }
            }
            .navigationTitle("Scan call sheet")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            #if canImport(PhotosUI)
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await handlePicked(newItem) }
                }
            #endif
        }
    }

    #if canImport(PhotosUI)
    @MainActor
    private func handlePicked(_ item: PhotosPickerItem) async {
        isBusy = true
        errorMessage = nil
        defer {
            isBusy = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Could not read the photo."
                return
            }
            #if canImport(UIKit)
            guard let img = UIImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                errorMessage = "Unsupported image."
                return
            }
            #elseif canImport(AppKit)
            guard let img = NSImage.rv_decodedNormalizingEXIFOrientation(from: data) else {
                errorMessage = "Unsupported image."
                return
            }
            #else
            errorMessage = "Imaging not available on this platform."
            return
            #endif
            let scan = try await ReceiptScanPipeline.processImported(
                image: img,
                ocrEnabled: ocrEnabled,
                compressionEnabled: compressionEnabled
            )
            let ocr = scan.combinedOCRText
            guard let pref = CallSheetHeaderParser.parseLaborPrefill(
                combinedOCR: ocr,
                anchorDayIfNoDateInOCR: Date()
            ) else {
                errorMessage =
                    "Could not find a **CREW CALL** time in the OCR. Try a sharper crop of the header block."
                return
            }
            libraryNavigationCoordinator.offerCallSheetLaborPrefill(pref)
            libraryNavigationCoordinator.navigateFromHome(.laborSentinel)
            dismiss()
        } catch {
            errorMessage = error.ratioVitaUserDescription
        }
    }
    #endif
}
