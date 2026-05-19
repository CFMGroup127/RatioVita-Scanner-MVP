@testable import RatioVita
import XCTest

final class ReceiptCabinetRoutingTests: XCTestCase {
    func testMobilWholeWordRoutesVehicles() {
        let raw = ReceiptCabinetRouting.suggestedCabinetKindRaw(
            taxCategory: nil,
            merchant: "Mobil Travel Centre #441",
            productionType: nil
        )
        XCTAssertEqual(raw, DocumentCabinet.vehicles.rawValue)
    }

    func testMobilePhoneDoesNotMatchMobilFuel() {
        let raw = ReceiptCabinetRouting.suggestedCabinetKindRaw(
            taxCategory: nil,
            merchant: "T-Mobile",
            productionType: nil
        )
        XCTAssertNil(raw)
    }
}
