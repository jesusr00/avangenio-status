import XCTest
@testable import AvangenioStatusKit

final class ScheduleEngineTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var engine: ScheduleEngine!

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        engine = ScheduleEngine(calendar: calendar)
    }

    // AE3: rango 8–18 cada 2h, martes 13:30 → próximo 14:00 el mismo día.
    func testRangeNextFireSameDay() {
        let now = date(2026, 8, 11, 13, 30)
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: now))!
        let schedule = Schedule(weekdays: [weekday], mode: .range(startHour: 8, startMinute: 0, endHour: 18, endMinute: 0, everyHours: 2))
        XCTAssertEqual(engine.nextFireDate(after: now, schedules: [schedule]), date(2026, 8, 11, 14, 0))
    }

    func testFixedTimeRollsToNextDay() {
        let now = date(2026, 8, 11, 9, 30)
        let schedule = Schedule(weekdays: Set(Weekday.allCases), mode: .fixedTime(hour: 9, minute: 0))
        XCTAssertEqual(engine.nextFireDate(after: now, schedules: [schedule]), date(2026, 8, 12, 9, 0))
    }

    func testWeekendExcluded() {
        let saturday = firstDate(weekday: .saturday, hour: 12)
        let schedule = Schedule(weekdays: Weekday.weekdays, mode: .fixedTime(hour: 9, minute: 0))
        let next = engine.nextFireDate(after: saturday, schedules: [schedule])!
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: next))!
        XCTAssertTrue(Weekday.weekdays.contains(weekday))
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
    }

    func testEndOfRangeRollsToNextValidDay() {
        // Justo después del último disparo (18:00) → primer disparo del siguiente día válido.
        let now = date(2026, 8, 11, 18, 30)
        let schedule = Schedule(weekdays: Set(Weekday.allCases), mode: .range(startHour: 8, startMinute: 0, endHour: 18, endMinute: 0, everyHours: 2))
        XCTAssertEqual(engine.nextFireDate(after: now, schedules: [schedule]), date(2026, 8, 12, 8, 0))
    }

    func testNoSchedulesReturnsNil() {
        XCTAssertNil(engine.nextFireDate(after: date(2026, 8, 11, 0, 0), schedules: []))
    }

    func testDisabledScheduleIgnored() {
        let schedule = Schedule(isEnabled: false, weekdays: Set(Weekday.allCases), mode: .fixedTime(hour: 9, minute: 0))
        XCTAssertNil(engine.nextFireDate(after: date(2026, 8, 11, 0, 0), schedules: [schedule]))
    }

    func testNearestOfMultipleSchedules() {
        let now = date(2026, 8, 11, 8, 0)
        let a = Schedule(weekdays: Set(Weekday.allCases), mode: .fixedTime(hour: 15, minute: 0))
        let b = Schedule(weekdays: Set(Weekday.allCases), mode: .fixedTime(hour: 10, minute: 0))
        XCTAssertEqual(engine.nextFireDate(after: now, schedules: [a, b]), date(2026, 8, 11, 10, 0))
    }

    func testZeroIntervalRangeProducesNoFires() {
        let schedule = Schedule(weekdays: Set(Weekday.allCases), mode: .range(startHour: 8, startMinute: 0, endHour: 18, endMinute: 0, everyHours: 0))
        XCTAssertNil(engine.nextFireDate(after: date(2026, 8, 11, 0, 0), schedules: [schedule]))
        XCTAssertTrue(engine.missedFires(since: date(2026, 8, 11, 0, 0), until: date(2026, 8, 11, 23, 0), schedules: [schedule]).isEmpty)
    }

    func testMissedFiresAcrossHours() {
        let since = date(2026, 8, 11, 7, 0)
        let until = date(2026, 8, 11, 15, 0)
        let schedule = Schedule(weekdays: Set(Weekday.allCases), mode: .range(startHour: 8, startMinute: 0, endHour: 18, endMinute: 0, everyHours: 2))
        let expected = [8, 10, 12, 14].map { date(2026, 8, 11, $0, 0) }
        XCTAssertEqual(engine.missedFires(since: since, until: until, schedules: [schedule]), expected)
    }

    // MARK: helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func firstDate(weekday: Weekday, hour: Int) -> Date {
        for day in 1...28 {
            let candidate = date(2026, 8, day, hour, 0)
            if calendar.component(.weekday, from: candidate) == weekday.rawValue {
                return candidate
            }
        }
        fatalError("no se encontró el día \(weekday)")
    }
}
