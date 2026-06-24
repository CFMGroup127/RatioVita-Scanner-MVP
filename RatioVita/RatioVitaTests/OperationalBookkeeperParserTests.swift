@testable import RatioVita
import XCTest

final class OperationalBookkeeperParserTests: XCTestCase {
    func testExtractsTotalDueFromCorpus() {
        let corpus = "Invoice from vendor Total Due: $1,234.56 HST 13%: $142.00 Subtotal: $1,092.56"
        let result = OperationalBookkeeperParserTestSupport.extractMonetary(from: corpus, currency: "CAD")
        XCTAssertEqual(result.gross, Decimal(string: "1234.56"))
        XCTAssertEqual(result.tax, Decimal(string: "142.00"))
        XCTAssertEqual(result.net, Decimal(string: "1092.56"))
    }

    func testDetectsCostcoVendorSignature() {
        let corpus = "COSTCO WHOLESALE #123 Toronto ON Total $89.99"
        XCTAssertEqual(
            OperationalBookkeeperParserTestSupport.matchVendor(in: corpus),
            "Costco Wholesale"
        )
    }

    func testCanadianTaxRegistration() {
        let corpus = "GST/HST Registration No: 123456789 RT0001 Total $500.00"
        XCTAssertEqual(
            OperationalBookkeeperParserTestSupport.taxRegistration(from: corpus),
            "123456789 RT0001"
        )
    }

    func testLogisticsPayrollFilenameMatch() {
        let hint = "[13TM - Payroll Info Sheet.pdf] crew hours"
        XCTAssertTrue(OperationalBookkeeperParserTestSupport.isLogisticsDocument(hint))
    }

    func testLogisticsSustainabilityMemoExtractsCostCode() {
        let corpus = """
        Sustainability Memo
        DEPT-4401 environmental supplies
        Employee: Jane Smith hours 8
        - LED panel recycling $250.00
        """
        let parsed = OperationalBookkeeperParserTestSupport.parseLogistics(corpus: corpus, hint: "Sustainability Memo.pdf")
        XCTAssertEqual(parsed.documentKind, "sustainability_memo")
        XCTAssertTrue(parsed.departmentalCostCodes.contains("DEPT-4401"))
        XCTAssertTrue(parsed.crewNameTokens.contains(where: { $0.contains("Jane") }))
    }
}

final class MileageLogTrackerTests: XCTestCase {
    func testCanadianKilometerDeduction() {
        let corpus = "Travel log Toronto to Hamilton 42.5 km odo 125000 CRA"
        let result = MileageLogTrackerTestSupport.parseCorpus(corpus, currency: "CAD", gross: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jurisdiction, .canadaCRA)
        XCTAssertEqual(result?.deductionRatePerUnit, Decimal(string: "0.70"))
        XCTAssertEqual(result?.estimatedDeduction, Decimal(string: "0.70")! * Decimal(42.5))
        XCTAssertEqual(result?.travelDeductionCategory, MileageLogTracker.travelDeductionCategory)
    }

    func testUSMileDeduction() {
        let corpus = "IRS mileage log 100 mi from LA to San Diego odometer 45000"
        let result = MileageLogTrackerTestSupport.parseCorpus(corpus, currency: "USD", gross: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.jurisdiction, .unitedStatesIRS)
        XCTAssertEqual(result?.deductionRatePerUnit, Decimal(string: "0.67"))
        XCTAssertEqual(result?.estimatedDeduction, Decimal(string: "0.67")! * Decimal(100))
    }

    func testOdometerDeltaCalculation() {
        let corpus = "Starting odo 12000 ending odo 12085 route: studio to location"
        let result = MileageLogTrackerTestSupport.parseCorpus(corpus, currency: "CAD", gross: 0)
        XCTAssertEqual(result?.distanceKilometers ?? 0, 85, accuracy: 0.01)
    }
}

// MARK: - Test hooks (file-private visibility via @testable)

enum OperationalBookkeeperParserTestSupport {
    static func extractMonetary(from corpus: String, currency: String) -> (
        gross: Decimal?,
        net: Decimal?,
        tax: Decimal?,
        registration: String?
    ) {
        // Mirror MonetaryExtractionRules via public parse path on synthetic receipt text in notes
        let receipt = Receipt(merchant: "Test", total: 0, currencyCode: currency, notes: corpus)
        let parsed = OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        )
        return (parsed.grossAmount, parsed.netAmount, parsed.taxAmount, parsed.canadianTaxRegistration)
    }

    static func matchVendor(in corpus: String) -> String? {
        let receipt = Receipt(merchant: corpus, total: 10)
        return OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        ).detectedVendorSignature
    }

    static func taxRegistration(from corpus: String) -> String? {
        let receipt = Receipt(merchant: "Test", total: 0, notes: corpus)
        return OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        ).canadianTaxRegistration
    }

    static func isLogisticsDocument(_ hint: String) -> Bool {
        let receipt = Receipt(merchant: hint, total: 0)
        let parsed = OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        )
        return parsed.logisticsDocumentKind != nil
    }

    static func parseLogistics(corpus: String, hint: String) -> (
        documentKind: String,
        departmentalCostCodes: [String],
        crewNameTokens: [String]
    ) {
        let receipt = Receipt(merchant: hint, total: 250, notes: corpus)
        let parsed = OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        )
        return (
            parsed.logisticsDocumentKind ?? "",
            parsed.departmentalCostCodes,
            parsed.crewNameTokens
        )
    }
}

enum MileageLogTrackerTestSupport {
    static func parseCorpus(_ corpus: String, currency: String, gross: Decimal) -> MileageLogTracker.MileageParseResult? {
        let receipt = Receipt(merchant: "Travel", total: gross, currencyCode: currency, notes: corpus)
        let parsed = OperationalBookkeeperParser.parse(
            receipt: receipt,
            scope: BookkeepingScope(productionPUID: nil, ventureEntityID: nil, requiresPUID: false, requiresVentureEntity: false)
        )
        return MileageLogTracker.parse(receipt: receipt, parsed: parsed)
    }
}
