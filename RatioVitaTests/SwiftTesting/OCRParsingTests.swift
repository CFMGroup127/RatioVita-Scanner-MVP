import Testing
@testable import RatioVita

@Suite("OCRParsing merchant/date/total extraction")
struct OCRParsingTests {

    @Test("Extracts merchant from first non-empty line")
    func extractsMerchant() async throws {
        let text = """
        ACME Market
        Total: $42.39
        Date: 02/02/2026
        """
        let data = OCRParsing.extractData(from: text)
        #expect(data.merchant == "ACME Market", "Merchant should be first line")
    }

    @Test("Extracts total from line containing $ or Total")
    func extractsTotal() async throws {
        let text = """
        Sample Store
        Items: 3
        Total: 100
        """
        let data = OCRParsing.extractData(from: text)
        #expect(data.total != nil, "Total should be parsed")
        #expect(data.total == Decimal(100), "Total should be 100")
    }

    @Test("RealScannerService-style OCR text yields merchant and total")
    func sampleReceiptStyleMerchantAndTotal() async throws {
        let ocrText = """
        ACME MARKET
        Date: 02/02/2026
        Total: 42.39
        Items: Apples, Bread, Milk
        """
        let data = OCRParsing.extractData(from: ocrText)
        #expect(data.merchant != nil, "Merchant should be identified from sample OCR")
        #expect(data.total != nil, "Total should be identified from sample OCR (parser extracts a numeric total)")
    }

    @Test("Returns nil merchant and total for empty or irrelevant text")
    func emptyTextReturnsNil() async throws {
        let data = OCRParsing.extractData(from: "")
        #expect(data.merchant == nil)
        #expect(data.total == nil)
    }
}
