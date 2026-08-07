import XCTest
@testable import AvangenioStatusKit

final class DateDisplayTests: XCTestCase {
    func testFormatsApiTimestampInSpanish() {
        // Doble espacio antes del día (formato real del API para días de 1 dígito).
        let result = DateDisplay.spanish(fromAPITimestamp: "Fri Aug  7 16:59:01 CDT 2026")
        XCTAssertTrue(result.contains("ago"), result)   // mes en español, no "Aug"
        XCTAssertTrue(result.contains("2026"), result)
        XCTAssertTrue(result.contains("16:59"), result) // misma hora reportada
        XCTAssertTrue(result.contains("CDT"), result)   // zona preservada
        XCTAssertFalse(result.contains("Aug"), result)
        XCTAssertFalse(result.contains("Fri"), result)
    }

    func testReturnsRawWhenUnparseable() {
        XCTAssertEqual(DateDisplay.spanish(fromAPITimestamp: "no es una fecha"), "no es una fecha")
    }
}
