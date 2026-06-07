import SwiftUI

#if canImport(PDFKit)
import PDFKit
#endif

/// Landscape US Letter timecard aspect (width ÷ height).
enum PayrollPDFPreviewLayout {
    static let landscapeAspect: CGFloat = 792.0 / 612.0
}

/// Preview of the **official** filled timecard PDF (same file as export — not a programmatic skeleton).
struct TimecardOfficialTemplatePreviewView: View {
    let format: TimecardPDFFormatKind
    let productionTitle: String
    let occupation: String
    let weekEnding: String
    let days: [CrewTimecardDay]
    let workRecords: [WorkRecord]
    let agreement: LaborAgreement
    let estimateByDayID: [UUID: SentinelPayEstimate]
    let production: ProductionProject?

    @State private var previewURL: URL?
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Official form underlay — \(format.rawValue)")
                .font(.caption.weight(.semibold))
                .adaptiveDetailText()

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .adaptiveDetailText()
            } else if let previewURL {
                #if canImport(PDFKit)
                PayrollPDFFitPageView(url: previewURL)
                #else
                Text("PDF preview requires PDFKit.")
                    .font(.caption)
                #endif
            } else {
                ProgressView("Rendering official template…")
                    .frame(minHeight: 120)
            }
        }
        .task(id: taskKey) {
            await renderPreview()
        }
    }

    private var taskKey: String {
        "\(format.id)-\(productionTitle)-\(days.count)-\(weekEnding)"
    }

    @MainActor
    private func renderPreview() async {
        loadError = nil
        previewURL = nil
        do {
            let url = try TimecardOfficialPDFComposer.writeFilledTimecard(
                template: format.officialTemplate,
                productionTitle: productionTitle,
                occupation: occupation.isEmpty ? nil : occupation,
                days: days,
                workRecords: workRecords,
                agreement: agreement,
                estimateByDayID: estimateByDayID,
                production: production
            )
            previewURL = url
        } catch {
            loadError =
                "Could not load bundled template “\(format.officialTemplate.bundleResourceName).pdf”. Add the file under Resources/PayrollTemplates. \(error.localizedDescription)"
        }
    }
}

#if canImport(PDFKit)
/// Shows one landscape page scaled to fit width — no vertical scroll for the sheet itself.
struct PayrollPDFFitPageView: View {
    let url: URL

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.width / PayrollPDFPreviewLayout.landscapeAspect
            PDFKitDocumentView(url: url, fitSinglePage: true)
                .frame(width: geo.size.width, height: height)
        }
        .aspectRatio(PayrollPDFPreviewLayout.landscapeAspect, contentMode: .fit)
        .frame(maxWidth: SafeLayoutBounds.maxTimecardPreviewWidth)
    }
}

#if canImport(AppKit)
/// Shared PDF viewer (macOS export sheet + template preview).
struct PDFKitDocumentView: NSViewRepresentable {
    let url: URL
    var fitSinglePage: Bool = false

    func makeNSView(context _: Context) -> PDFView {
        let v = PDFView()
        v.displayMode = fitSinglePage ? .singlePage : .singlePageContinuous
        v.displayDirection = .vertical
        v.displaysPageBreaks = false
        v.displaysAsBook = false
        v.autoScales = true
        v.document = PDFDocument(url: url)
        return v
    }

    func updateNSView(_ nsView: PDFView, context _: Context) {
        let document = PDFDocument(url: url)
        if fitSinglePage, let document {
            PDFFormFieldStyle.reinforceGridWidgetTypography(document: document)
        }
        nsView.document = document
        nsView.displayMode = fitSinglePage ? .singlePage : .singlePageContinuous
        nsView.displaysPageBreaks = false
        if fitSinglePage, let page = nsView.document?.page(at: 0) {
            nsView.go(to: page)
            DispatchQueue.main.async {
                nsView.scaleFactor = nsView.scaleFactorForSizeToFit
            }
        }
        nsView.autoScales = true
    }
}

#elseif canImport(UIKit)
struct PDFKitDocumentView: UIViewRepresentable {
    let url: URL
    var fitSinglePage: Bool = false

    func makeUIView(context _: Context) -> PDFView {
        let v = PDFView()
        v.displayMode = fitSinglePage ? .singlePage : .singlePageContinuous
        v.displayDirection = .vertical
        v.displaysPageBreaks = false
        v.displaysAsBook = false
        v.autoScales = true
        v.document = PDFDocument(url: url)
        return v
    }

    func updateUIView(_ uiView: PDFView, context _: Context) {
        uiView.document = PDFDocument(url: url)
        uiView.displayMode = fitSinglePage ? .singlePage : .singlePageContinuous
        uiView.displaysPageBreaks = false
        if fitSinglePage, let page = uiView.document?.page(at: 0) {
            uiView.go(to: page)
            DispatchQueue.main.async {
                uiView.scaleFactor = uiView.scaleFactorForSizeToFit
            }
        }
        uiView.autoScales = true
    }
}
#endif
#endif
