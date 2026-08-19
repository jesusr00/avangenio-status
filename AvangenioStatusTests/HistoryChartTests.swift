import XCTest
@testable import AvangenioStatusKit

final class HistoryChartTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func sample(_ offsetSeconds: TimeInterval, battery: Double?, power: PowerStatus = .on) -> EnergySample {
        EnergySample(timestamp: now.addingTimeInterval(offsetSeconds), batteryPercent: battery, power: power)
    }

    func testDomainBounds() {
        let data = HistoryChart.build(samples: [], range: .day, now: now)
        XCTAssertEqual(data.start, now.addingTimeInterval(-86_400))
        XCTAssertEqual(data.end, now)
    }

    func testEmptyReturnsNoSegments() {
        let data = HistoryChart.build(samples: [], range: .week, now: now)
        XCTAssertTrue(data.batterySegments.isEmpty)
    }

    func testFiltersOutOfRange() {
        let inside = sample(-3_600, battery: 80)          // hace 1 h
        let outside = sample(-2 * 86_400, battery: 50)    // hace 2 días
        let data = HistoryChart.build(samples: [outside, inside], range: .day, now: now)
        XCTAssertEqual(data.batterySegments, [[BatteryPoint(timestamp: inside.timestamp, percent: 80)]])
    }

    func testDenseSamplesFormSingleSegment() {
        let s = [sample(-1_800, battery: 90), sample(-1_200, battery: 85), sample(-600, battery: 80)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 1)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90, 85, 80])
    }

    func testBreaksOnTimeGap() {
        // 40 min entre muestras > umbral 25 min → dos segmentos.
        let s = [sample(-4_800, battery: 90), sample(-2_400, battery: 70)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 2)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90])
        XCTAssertEqual(data.batterySegments[1].map(\.percent), [70])
    }

    func testBreaksOnNilBattery() {
        let s = [sample(-1_800, battery: 90), sample(-1_200, battery: nil), sample(-600, battery: 80)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 2)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90])
        XCTAssertEqual(data.batterySegments[1].map(\.percent), [80])
    }

    func testSortsUnorderedInput() {
        let s = [sample(-600, battery: 80), sample(-1_800, battery: 90), sample(-1_200, battery: 85)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90, 85, 80])
    }

    func testEmptyReturnsNoBands() {
        let data = HistoryChart.build(samples: [], range: .day, now: now)
        XCTAssertTrue(data.powerBands.isEmpty)
    }

    func testSingleBandExtendsToNow() {
        let s = [sample(-1_800, battery: 90, power: .on), sample(-600, battery: 80, power: .on)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: now, state: .on)
        ])
    }

    func testTwoBandsOnTransition() {
        let s = [sample(-1_800, battery: 90, power: .on), sample(-600, battery: 80, power: .off)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: s[1].timestamp, state: .on),
            PowerBand(start: s[1].timestamp, end: now, state: .off),
        ])
    }

    func testBandsIgnoreNilBattery() {
        // Un hueco de batería (nil) no debe partir las bandas eléctricas.
        let s = [sample(-1_800, battery: 90, power: .off),
                 sample(-1_200, battery: nil, power: .off),
                 sample(-600, battery: 80, power: .off)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: now, state: .off)
        ])
    }
}
