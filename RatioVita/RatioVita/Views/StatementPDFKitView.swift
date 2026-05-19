//
//  StatementPDFKitView.swift
//  RatioVita
//
//  Embedded PDFKit viewer for bank statement PDFs in reconciliation (continuous vertical pages).
//

import SwiftUI

#if canImport(PDFKit)
import PDFKit

#if canImport(UIKit)
import UIKit

struct StatementPDFKitView: UIViewRepresentable {
    let url: URL
    /// 0 = start of document, 1 = end; coarse scroll target for “zoom to row”.
    var approximateVerticalFraction: CGFloat?
    /// Bump to re-apply scroll for the same fraction (button taps).
    var scrollRequestToken: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.displayBox = .mediaBox
        v.backgroundColor = .secondarySystemBackground
        return v
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        let path = url.path
        if context.coordinator.loadedPath != path {
            context.coordinator.loadedPath = path
            pdfView.document = PDFDocument(url: url)
        }
        guard let token = scrollRequestToken, token != context.coordinator.lastScrollToken else { return }
        context.coordinator.lastScrollToken = token
        Self.scrollToApproximateVerticalFraction(in: pdfView, fraction: approximateVerticalFraction ?? 0.5)
    }

    private static func scrollToApproximateVerticalFraction(in pdfView: PDFView, fraction: CGFloat) {
        guard let doc = pdfView.document, doc.pageCount > 0 else { return }
        let f = max(0, min(1, fraction))
        let pageIndex = min(doc.pageCount - 1, max(0, Int((f * CGFloat(doc.pageCount)).rounded(.down))))
        guard let page = doc.page(at: pageIndex) else { return }
        pdfView.go(to: page)
        let bounds = page.bounds(for: .mediaBox)
        let y = max(0, bounds.maxY * (1 - f) - bounds.height * 0.15)
        let rect = CGRect(
            x: bounds.minX + 4,
            y: y,
            width: max(bounds.width - 8, 40),
            height: min(bounds.height * 0.35, 180)
        )
        pdfView.go(to: rect, on: page)
    }

    final class Coordinator {
        var loadedPath: String?
        var lastScrollToken: UUID?
    }
}

#elseif canImport(AppKit)
import AppKit

struct StatementPDFKitView: NSViewRepresentable {
    let url: URL
    var approximateVerticalFraction: CGFloat?
    var scrollRequestToken: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context _: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.displayBox = .mediaBox
        v.backgroundColor = .textBackgroundColor
        return v
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        let path = url.path
        if context.coordinator.loadedPath != path {
            context.coordinator.loadedPath = path
            pdfView.document = PDFDocument(url: url)
        }
        guard let token = scrollRequestToken, token != context.coordinator.lastScrollToken else { return }
        context.coordinator.lastScrollToken = token
        Self.scrollToApproximateVerticalFraction(in: pdfView, fraction: approximateVerticalFraction ?? 0.5)
    }

    private static func scrollToApproximateVerticalFraction(in pdfView: PDFView, fraction: CGFloat) {
        guard let doc = pdfView.document, doc.pageCount > 0 else { return }
        let f = max(0, min(1, fraction))
        let pageIndex = min(doc.pageCount - 1, max(0, Int((f * CGFloat(doc.pageCount)).rounded(.down))))
        guard let page = doc.page(at: pageIndex) else { return }
        pdfView.go(to: page)
        let bounds = page.bounds(for: .mediaBox)
        let y = max(0, bounds.maxY * (1 - f) - bounds.height * 0.15)
        let rect = CGRect(
            x: bounds.minX + 4,
            y: y,
            width: max(bounds.width - 8, 40),
            height: min(bounds.height * 0.35, 180)
        )
        pdfView.go(to: rect, on: page)
    }

    final class Coordinator {
        var loadedPath: String?
        var lastScrollToken: UUID?
    }
}
#endif
#endif
