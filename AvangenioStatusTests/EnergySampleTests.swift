import XCTest
@testable import AvangenioStatusKit

final class EnergySampleTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let sample = EnergySample(timestamp: Date(timeIntervalSince1970: 1000),
                                  batteryPercent: 62.5, power: .off)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(EnergySample.self, from: data)
        XCTAssertEqual(decoded, sample)
    }

    func testNilBatteryRoundTrip() throws {
        let sample = EnergySample(timestamp: Date(timeIntervalSince1970: 1000),
                                  batteryPercent: nil, power: .on)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(EnergySample.self, from: data)
        XCTAssertNil(decoded.batteryPercent)
        XCTAssertEqual(decoded, sample)
    }

    func testRangeDurations() {
        XCTAssertEqual(HistoryRange.day.duration, 86_400)
        XCTAssertEqual(HistoryRange.week.duration, 604_800)
        XCTAssertEqual(HistoryRange.month.duration, 2_592_000)
    }

    func testRangeIsCaseIterable() {
        XCTAssertEqual(HistoryRange.allCases, [.day, .week, .month])
    }
}
