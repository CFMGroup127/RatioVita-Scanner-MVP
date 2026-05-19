//
//  ImageProcessingTests.swift
//  RatioVitaTests
//
//  Verifies ImageProcessing pipeline (Task 10).
//

@testable import RatioVita
import XCTest

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class ImageProcessingTests: XCTestCase {
    func testProcessImageReturnsImage() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 100, height: 100)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 100, height: 100)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        #else
        throw XCTSkip("No image type available")
        #endif

        let result = try await ImageProcessing.processImage(img, with: .receiptDefault)
        XCTAssertNotNil(result, "processImage should return an image")
    }

    func testProcessImageReceiptDefaultDoesNotCrash() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 40, height: 40)
        let img = UIGraphicsImageRenderer(size: size).image { _ in }
        #elseif canImport(AppKit)
        let size = NSSize(width: 40, height: 40)
        let img = NSImage(size: size)
        #else
        throw XCTSkip("No image type available")
        #endif

        _ = try await ImageProcessing.processImage(img, with: .receiptDefault)
    }

    /// Sovereign enhancement should yield a valid bitmap (Core Image path exercised).
    func testProcessImageProducesCGImage() async throws {
        #if canImport(UIKit)
        let size = CGSize(width: 32, height: 32)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 32, height: 32)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.darkGray.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        img.unlockFocus()
        #else
        throw XCTSkip("No image type available")
        #endif

        let processed = try await ImageProcessing.processImage(img, with: .receiptDefault)
        XCTAssertNotNil(processed.rvCGImage, "Core Image pipeline should produce a CGImage-backed result")
    }
}
