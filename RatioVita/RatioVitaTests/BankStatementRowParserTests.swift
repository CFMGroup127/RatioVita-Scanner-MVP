@testable import RatioVita
import XCTest

final class BankStatementRowParserTests: XCTestCase {
    func testFlipNegativeAmountToPositiveCredit() {
        let payload = GeminiBankStatementPayload(
            rows: [
                .init(postedDate: "2024-06-01", description: "Shell", amount: -42.50, currency: "CAD"),
            ],
            defaultCurrency: "CAD"
        )
        let rows = BankStatementRowParser.rows(from: payload, defaultCurrency: "CAD")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].amount, 42.50)
    }

    /// Model returned a positive credit; global flip makes it negative — income memo forces credit polarity back.
    func testPaymentReceivedMemoCorrectsDoubleInvertedCredit() {
        let payload = GeminiBankStatementPayload(
            rows: [
                .init(postedDate: "2024-06-02", description: "Invoice payment — ACME", amount: 1200, currency: "CAD"),
            ],
            defaultCurrency: "CAD"
        )
        let rows = BankStatementRowParser.rows(from: payload, defaultCurrency: "CAD")
        XCTAssertEqual(rows.count, 1)
        XCTAssertGreaterThan(rows[0].amount, 0)
        XCTAssertEqual(rows[0].amount, 1200)
    }

    func testPurchaseMemoDoesNotFlipDebitToCredit() {
        let payload = GeminiBankStatementPayload(
            rows: [
                .init(postedDate: "2024-06-03", description: "POS purchase", amount: 19.99, currency: "CAD"),
            ],
            defaultCurrency: "CAD"
        )
        let rows = BankStatementRowParser.rows(from: payload, defaultCurrency: "CAD")
        XCTAssertEqual(rows.count, 1)
        XCTAssertLessThan(rows[0].amount, 0)
    }

    /// After the global Gemini flip, a **debit** described as POS that landed positive is forced negative.
    func testPOSPurchasePositiveAmountForcedNegative() {
        let payload = GeminiBankStatementPayload(
            rows: [
                .init(
                    postedDate: "2024-06-04",
                    description: "POS purchase — STORE 12",
                    amount: -44.44,
                    currency: "CAD"
                ),
            ],
            defaultCurrency: "CAD"
        )
        let rows = BankStatementRowParser.rows(from: payload, defaultCurrency: "CAD")
        XCTAssertEqual(rows.count, 1)
        XCTAssertLessThan(rows[0].amount, 0)
    }
}
