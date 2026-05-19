@testable import RatioVita
import XCTest

final class AccountingAmountPolarityTests: XCTestCase {
    func testIncomeTypesForcePositive() {
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .incomeOrCheck, amount: -500),
            500
        )
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .outgoingInvoice, amount: -1),
            1
        )
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .paycheck, amount: 2400),
            2400
        )
    }

    func testExpenseTypesForceNegative() {
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .receipt, amount: 42.10),
            -42.10
        )
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .invoice, amount: -99),
            -99
        )
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .fuel, amount: 55),
            -55
        )
    }

    func testNeutralTypesDoNotFlip() {
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .timeSheet, amount: 0),
            0
        )
        XCTAssertEqual(
            AccountingAmountPolarity.validateSign(documentType: .statement, amount: -12),
            -12
        )
    }
}
