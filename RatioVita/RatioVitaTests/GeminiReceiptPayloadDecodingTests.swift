@testable import RatioVita
import XCTest

@MainActor
final class GeminiReceiptPayloadDecodingTests: XCTestCase {
    func testDecodesBedBathBeyondStylePayload() throws {
        let json = """
        {
          "merchant": "BED BATH & BEYOND #2038",
          "vendorAddress": "1602 The Queensway, Toronto, ON",
          "documentNumber": null,
          "transactionDate": "2018-12-24",
          "subtotal": 55.99,
          "taxAmount": 7.28,
          "total": 63.27,
          "currency": "CAD",
          "paymentMethod": "DEBIT",
          "documentKind": "receipt",
          "lineItems": [
            { "description": "FIRESIDE MAT 24X36", "quantity": 1, "unitPrice": 55.99, "totalPrice": 55.99, "serialNumber": null }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(GeminiReceiptPayload.self, from: data)
        XCTAssertEqual(payload.total, 63.27)
        XCTAssertEqual(payload.taxAmount, 7.28)
        XCTAssertEqual(payload.transactionDate, "2018-12-24")
        XCTAssertEqual(payload.lineItems?.count, 1)
        XCTAssertEqual(payload.lineItems?.first?.description, "FIRESIDE MAT 24X36")
    }

    func testDecodesWorkDaysPayload() throws {
        let json = """
        {
          "merchant": "ACME PRODUCTIONS PAYROLL",
          "transactionDate": null,
          "total": null,
          "currency": "CAD",
          "documentKind": "time_sheet",
          "work_days": [
            { "date": "2025-01-06", "hours": 10.5, "showTitle": "The Sequoia" },
            { "date": "2025-01-07", "hours": 12, "showTitle": null }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(GeminiReceiptPayload.self, from: data)
        XCTAssertEqual(payload.workDays?.count, 2)
        XCTAssertEqual(payload.workDays?.first?.date, "2025-01-06")
        XCTAssertEqual(payload.workDays?.first?.hours, 10.5)
    }
}
