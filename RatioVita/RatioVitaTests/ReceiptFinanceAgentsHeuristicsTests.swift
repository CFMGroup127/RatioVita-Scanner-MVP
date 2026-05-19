@testable import RatioVita
import XCTest

final class ReceiptFinanceAgentsHeuristicsTests: XCTestCase {
    func testCraftCateringMapsToTaxCategory() {
        let corpus = "Bespoke Craft and Catering craft services invoice"
        XCTAssertEqual(
            ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus),
            "CraftServices_Catering"
        )
    }

    func testCostumeKeyword() {
        let corpus = "WARDROBE purchase costumes department"
        XCTAssertEqual(
            ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus),
            "Costumes_Wardrobe"
        )
    }

    func testGLCodeForCraft() {
        XCTAssertEqual(
            ReceiptFinanceAgentsHeuristics.suggestGLCode(fromCorpus: "catering supplies"),
            "GL-5210-CRAFT"
        )
    }

    func testGLReturnsNilWhenUnknown() {
        XCTAssertNil(ReceiptFinanceAgentsHeuristics.suggestGLCode(fromCorpus: "miscellaneous xyz"))
    }
}
