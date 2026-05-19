@testable import RatioVita
import XCTest

final class DealMemoSniperTests: XCTestCase {
    func testParsesEPStartSlipFlatRate() {
        let ocr = """
        ep Entertainment Partners
        Start Slip and Waiver - Corporation/Loan-out
        Show Title: See for Me
        Production Company: See For Me Film Inc.
        Employee Name: Collin Morris
        Company Name: Bespoke Craft and Catering Services Inc
        GST/HST #: 76001212 RT0001
        Position: Craft Chef
        Department: Craft
        Start Date: Mar 9, 2020
        NON-UNION
        Rate $300 Per Day
        14 Hours
        Production Manager Approval: KRISTY NEVILLE
        """
        let payload = DealMemoSniper.parsePage1(combinedOCR: ocr)
        guard let payload else {
            return XCTFail("DealMemoSniper returned nil for EP start slip fixture")
        }
        XCTAssertEqual(payload.positionTitle, "Craft Chef")
        XCTAssertEqual(payload.rateKind, .flatDaily)
        XCTAssertEqual(payload.flatDailyRateCAD, Decimal(300))
        XCTAssertGreaterThanOrEqual(payload.flatGuaranteeHours ?? 0, 1)
    }

    func testParsesIndieHourlyDealTerms() {
        let ocr = """
        PRODUCTION PERSONNEL SERVICES AGREEMENT DEAL TERMS
        Production OUTSTANDING
        OS FILM ONTARIO INC.
        Position: BG set assistant Costumes
        Department: Costumes
        Term of Engagement: Hourly X
        Applicable Rate: 33.68
        Start Date: May 16, 2024
        Location of Engagement: Hamilton Ontario
        """
        let payload = DealMemoSniper.parsePage1(combinedOCR: ocr)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.showTitle, "Outstanding")
        XCTAssertEqual(payload?.rateKind, .hourly)
        XCTAssertEqual(payload?.hourlyRateCAD, Decimal(string: "33.68"))
        XCTAssertEqual(payload?.department, "Costumes")
    }

    func testHarvestsKitRentalRates() {
        let ocr = """
        DEAL MEMO — SEE FOR ME
        Show Title: See For Me
        Position: Camera Operator
        Cell Phone Kit Rental: $25.00 per day
        Laptop Kit: $40.00
        iPad / Tablet: $15.00 daily
        Applicable Rate: $62.50 per hour
        """
        let payload = DealMemoSniper.parsePage1(combinedOCR: ocr)
        guard let payload else {
            return XCTFail("DealMemoSniper returned nil for kit rental fixture")
        }
        XCTAssertEqual(
            payload.kitPhoneRateCAD,
            Decimal(string: "25.00"),
            "phone was \(String(describing: payload.kitPhoneRateCAD))"
        )
        XCTAssertEqual(
            payload.kitLaptopRateCAD,
            Decimal(string: "40.00"),
            "laptop was \(String(describing: payload.kitLaptopRateCAD))"
        )
        XCTAssertEqual(
            payload.kitTabletRateCAD,
            Decimal(string: "15.00"),
            "tablet was \(String(describing: payload.kitTabletRateCAD))"
        )
    }

    func testTaxRegistrationAnchorNormalizesBN() {
        XCTAssertEqual(
            TaxRegistrationAnchor.normalizedBusinessNumber(from: "76001212 RT0001"),
            "76001212"
        )
    }
}
