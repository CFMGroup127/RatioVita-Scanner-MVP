//
//  OCRParsingTests.swift
//  RatioVitaTests
//
//  Verifies OCRParsing extracts merchant and total from sample OCR text
//  (Task 10: RealScannerService correctly identifies Total and Merchant)
//

@testable import RatioVita
import XCTest

final class OCRParsingTests: XCTestCase {
    func testExtractsMerchantFromFirstNonEmptyLine() {
        let text = """
        ACME Market
        Total: $42.39
        Date: 02/02/2026
        """
        let data = OCRParsing.extractData(from: text)
        XCTAssertEqual(data.merchant, "ACME Market", "Merchant should be first line")
    }

    func testExtractsTotalFromLineContainingTotal() {
        let text = """
        Sample Store
        Items: 3
        Total: 100
        """
        let data = OCRParsing.extractData(from: text)
        XCTAssertNotNil(data.total, "Total should be parsed")
        XCTAssertEqual(data.total, Decimal(100), "Total should be 100")
    }

    func testSampleReceiptStyleYieldsMerchantAndTotal() {
        let ocrText = """
        ACME MARKET
        Date: 02/02/2026
        Total: 42.39
        Items: Apples, Bread, Milk
        """
        let data = OCRParsing.extractData(from: ocrText)
        XCTAssertNotNil(data.merchant, "Merchant should be identified from sample OCR")
        XCTAssertNotNil(data.total, "Total should be identified from sample OCR")
    }

    func testEmptyTextReturnsNilMerchantAndTotal() {
        let data = OCRParsing.extractData(from: "")
        XCTAssertNil(data.merchant)
        XCTAssertNil(data.total)
    }
}
