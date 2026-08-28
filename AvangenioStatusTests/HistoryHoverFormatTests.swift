import XCTest
@testable import AvangenioStatusKit

final class HistoryHoverFormatTests: XCTestCase {
    // 1970-01-12 13:46:40 UTC.
    private let instant = Date(timeIntervalSince1970: 1_000_000)
    private let utc = TimeZone(identifier: "UTC")!

    // MARK: - Hora según el rango

    func testDayRangeShowsOnlyTime() {
        XCTAssertEqual(
            HistoryHoverFormat.timestamp(instant, range: .day, timeZone: utc),
            "13:46"
        )
    }

    func testWeekRangeAddsTheDate() {
        let text = HistoryHoverFormat.timestamp(instant, range: .week, timeZone: utc)

        XCTAssertTrue(text.hasPrefix("12 "), "debe empezar por el día del mes: \(text)")
        XCTAssertTrue(text.hasSuffix("13:46"), "debe terminar en la hora: \(text)")
        XCTAssertNotEqual(text, HistoryHoverFormat.timestamp(instant, range: .day, timeZone: utc))
    }

    func testMonthRangeAddsTheDate() {
        let text = HistoryHoverFormat.timestamp(instant, range: .month, timeZone: utc)

        XCTAssertTrue(text.hasPrefix("12 "), "debe empezar por el día del mes: \(text)")
        XCTAssertTrue(text.hasSuffix("13:46"), "debe terminar en la hora: \(text)")
    }

    // MARK: - Duración de cortes

    func testDurationWithHoursAndMinutes() {
        XCTAssertEqual(HistoryHoverFormat.duration(3 * 3_600 + 20 * 60), "3 h 20 min")
    }

    func testDurationUnderOneHour() {
        XCTAssertEqual(HistoryHoverFormat.duration(45 * 60), "45 min")
    }

    func testDurationOnExactHourOmitsMinutes() {
        XCTAssertEqual(HistoryHoverFormat.duration(2 * 3_600), "2 h")
    }

    func testDurationRoundsDownToWholeMinutes() {
        XCTAssertEqual(HistoryHoverFormat.duration(119), "1 min")
    }

    func testDurationZero() {
        XCTAssertEqual(HistoryHoverFormat.duration(0), "0 min")
    }

    func testNegativeDurationIsClampedToZero() {
        XCTAssertEqual(HistoryHoverFormat.duration(-60), "0 min")
    }
}
