@testable import RatioVita
import XCTest

final class ChequeStubParserTests: XCTestCase {
    func testBellMediaCorporateStub() {
        let ocr = """
        Payé au nom de/Paid on behalf of Bell Media Inc.
        FACTURE / INVOICE    DATE         REF. DOCUMENT    MONTANT BRUT
        8011                 2019-04-26   8001216205     405.92
        MONTANT PAYE / NET PAYMENT 405.92
        FOURNISSEUR / VENDOR 20109005
        NO DU CHÈQUE / CHEQUE NO 0000010215551
        DATE 2020-06-10
        Banque de Montréal / Bank of Montreal
        To the order of / À l'ordre de BESPOKE CRAFT AND CATERING SERVICES INC.
        2927 LAKESHORE BLVD W. SUITE 248, TORONTO, ON M8W 1J3
        **********405 Dollars 92 Cents
        """

        let stub = ChequeStubParser.parse(combinedOCR: ocr)
        guard let stub else {
            return XCTFail("ChequeStubParser returned nil for Bell Media fixture")
        }
        XCTAssertEqual(stub.chequeNumber, "0000010215551")
        XCTAssertEqual(stub.internalInvoiceNumber, "8011")
        XCTAssertEqual(stub.clientAccountingToken, "8001216205")
        XCTAssertEqual(stub.payorName, "Bell Media Inc.")
        XCTAssertTrue(stub.payeeName?.localizedCaseInsensitiveContains("BESPOKE") == true)
    }

    func testNonChequeDoesNotMatch() {
        let ocr = "ACME HARDWARE\nTOTAL 42.99\nThank you"
        XCTAssertNil(ChequeStubParser.parse(combinedOCR: ocr))
    }
}
