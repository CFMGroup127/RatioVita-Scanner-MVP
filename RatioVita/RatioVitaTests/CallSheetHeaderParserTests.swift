import Foundation
import Testing

@testable import RatioVita

@Suite("CallSheetHeaderParser")
struct CallSheetHeaderParserTests {
    @Test func parsesCryWolfStyleHeader() {
        let ocr = """
        THE SYSTEM
        BLOCK 4 (EP 107 / 108)
        DAY 19 of 19
        Friday, May 15th, 2026
        CREW CALL 1400
        LOCATION 1: 1340 Oak Lane – Mississauga ON M5G 1M8
        """
        let anchor = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_768_000_000))
        let pref = CallSheetHeaderParser.parseLaborPrefill(combinedOCR: ocr, anchorDayIfNoDateInOCR: anchor)
        #expect(pref != nil)
        #expect(pref?.crewCallHour == 14)
        #expect(pref?.crewCallMinute == 0)
        #expect(pref?.setLocationLine?.contains("1340 Oak") == true)
        #expect(pref?.productionTitleLine == "THE SYSTEM")
    }

    @Test func bespokeOutgoingInvoiceHardLock() {
        let kind = RegistryEntityPolarity.bespokeForensicHardLockOutgoingInvoice(
            documentKind: "invoice",
            merchant: "Bespoke Craft and Catering",
            payee: nil,
            payor: nil,
            supplementalOCR: "Tax invoice #123"
        )
        #expect(kind == "outgoing_invoice")
    }

    @Test func bespokeDoesNotOverrideCheque() {
        let kind = RegistryEntityPolarity.bespokeForensicHardLockOutgoingInvoice(
            documentKind: "income",
            merchant: "Bespoke",
            payee: "Pay to the order of",
            payor: nil,
            supplementalOCR: "Pay to the order of Jane Doe"
        )
        #expect(kind == nil)
    }
}
