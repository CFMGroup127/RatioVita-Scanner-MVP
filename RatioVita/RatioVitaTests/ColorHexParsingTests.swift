//
//  ColorHexParsingTests.swift
//  RatioVitaTests
//
//  Ensures #RRGGBB strings parse correctly (regression: count must not include '#').
//

@testable import RatioVita
import SwiftUI
import XCTest

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

final class ColorHexParsingTests: XCTestCase {
    func testHexWithPoundPrefixParsesExpectedGreen() {
        let c = Color(hex: "#2E7D32")
        #if canImport(AppKit)
        let n = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
        XCTAssertEqual(Int((n.redComponent * 255).rounded()), 46)
        XCTAssertEqual(Int((n.greenComponent * 255).rounded()), 125)
        XCTAssertEqual(Int((n.blueComponent * 255).rounded()), 50)
        #elseif canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(Int((r * 255).rounded()), 46)
        XCTAssertEqual(Int((g * 255).rounded()), 125)
        XCTAssertEqual(Int((b * 255).rounded()), 50)
        #endif
    }

    func testHexWithoutHashParsesRed() {
        let c = Color(hex: "FF0000")
        #if canImport(AppKit)
        let n = NSColor(c).usingColorSpace(.sRGB) ?? NSColor(c)
        XCTAssertEqual(Int((n.redComponent * 255).rounded()), 255)
        XCTAssertEqual(Int((n.greenComponent * 255).rounded()), 0)
        XCTAssertEqual(Int((n.blueComponent * 255).rounded()), 0)
        #elseif canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(Int((r * 255).rounded()), 255)
        XCTAssertEqual(Int((g * 255).rounded()), 0)
        XCTAssertEqual(Int((b * 255).rounded()), 0)
        #endif
    }
}
