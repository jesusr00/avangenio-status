import XCTest
@testable import AvangenioStatusKit

final class StatusParserTests: XCTestCase {
    private let parser = StatusParser(now: { Date(timeIntervalSince1970: 0) })

    func testParsesRealSample() {
        let text = """
        Ultima actualizacion: Fri Aug  7 12:19:01 CDT 2026
        Internet Status: OK
        Ancho de Banda por Usuario: 4.42 Mbps
        Estado de las baterías: 26.00%
        Servicio Eléctrico Estatal: NO
        """
        let status = parser.parse(text)
        XCTAssertEqual(status?.lastUpdatedRaw, "Fri Aug  7 12:19:01 CDT 2026")
        XCTAssertEqual(status?.internet, .ok)
        XCTAssertEqual(status?.bandwidthMbps, 4.42)
        XCTAssertEqual(status?.batteryPercent, 26.0)
        XCTAssertEqual(status?.power, .off)
    }

    func testInternetDownWhenNotOK() {
        XCTAssertEqual(parser.parse(sample(internet: "DOWN"))?.internet, .down)
    }

    func testPowerYesMapsToOn() {
        XCTAssertEqual(parser.parse(sample(power: "YES"))?.power, .on)
    }

    func testPowerSiMapsToOn() {
        XCTAssertEqual(parser.parse(sample(power: "SI"))?.power, .on)
    }

    func testPowerSiWithAccentMapsToOn() {
        XCTAssertEqual(parser.parse(sample(power: "SÍ"))?.power, .on)
    }

    func testPowerNoMapsToOff() {
        XCTAssertEqual(parser.parse(sample(power: "NO"))?.power, .off)
    }

    func testTolerantSpacing() {
        let text = "Ultima actualizacion:   x\nInternet Status:    OK\nServicio Eléctrico Estatal:   NO"
        XCTAssertEqual(parser.parse(text)?.internet, .ok)
        XCTAssertEqual(parser.parse(text)?.power, .off)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(parser.parse(""))
    }

    func testMissingRequiredLineReturnsNil() {
        let text = "Ultima actualizacion: x\nServicio Eléctrico Estatal: NO"  // sin internet
        XCTAssertNil(parser.parse(text))
    }

    func testUnparseableBandwidthIsNilRestParses() {
        let status = parser.parse(sample(bandwidth: "sin datos"))
        XCTAssertNil(status?.bandwidthMbps)
        XCTAssertEqual(status?.internet, .ok)
    }

    func testNumberFormats() {
        XCTAssertEqual(StatusParser.firstNumber(in: "26.00%"), 26.0)
        XCTAssertEqual(StatusParser.firstNumber(in: "26%"), 26.0)
        XCTAssertEqual(StatusParser.firstNumber(in: "4,42 Mbps"), 4.42)
        XCTAssertNil(StatusParser.firstNumber(in: "sin datos"))
    }

    // MARK: helper

    private func sample(
        internet: String = "OK",
        bandwidth: String = "4.42 Mbps",
        battery: String = "26.00%",
        power: String = "NO"
    ) -> String {
        """
        Ultima actualizacion: x
        Internet Status: \(internet)
        Ancho de Banda por Usuario: \(bandwidth)
        Estado de las baterías: \(battery)
        Servicio Eléctrico Estatal: \(power)
        """
    }
}
