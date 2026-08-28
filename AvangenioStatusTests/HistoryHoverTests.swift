import XCTest
@testable import AvangenioStatusKit

final class HistoryHoverTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func sample(_ offsetSeconds: TimeInterval, battery: Double?, power: PowerStatus = .on) -> EnergySample {
        EnergySample(timestamp: now.addingTimeInterval(offsetSeconds), batteryPercent: battery, power: power)
    }

    private func at(_ offsetSeconds: TimeInterval) -> Date {
        now.addingTimeInterval(offsetSeconds)
    }

    private func data(_ samples: [EnergySample]) -> HistoryChartData {
        HistoryChart.build(samples: samples, range: .day, now: now)
    }

    // MARK: - Anclaje a muestra real

    func testAnchorsToNearestSample() {
        let d = data([sample(-3_600, battery: 90), sample(-3_000, battery: 85), sample(-2_400, battery: 80)])
        let reading = HistoryHover.reading(at: at(-3_100), in: d)

        XCTAssertEqual(reading.anchor, at(-3_000))
        XCTAssertEqual(reading.content, .reading(percent: 85, power: .on, outage: nil))
    }

    func testAnchorsToPreviousSampleWhenItIsCloser() {
        let d = data([sample(-3_600, battery: 90), sample(-3_000, battery: 85)])
        let reading = HistoryHover.reading(at: at(-3_500), in: d)

        XCTAssertEqual(reading.anchor, at(-3_600))
        XCTAssertEqual(reading.content, .reading(percent: 90, power: .on, outage: nil))
    }

    func testAnchorsExactlyOnSample() {
        let d = data([sample(-3_600, battery: 90), sample(-3_000, battery: 85)])
        let reading = HistoryHover.reading(at: at(-3_000), in: d)

        XCTAssertEqual(reading.anchor, at(-3_000))
        XCTAssertEqual(reading.content, .reading(percent: 85, power: .on, outage: nil))
    }

    func testSingleSampleSegment() {
        let d = data([sample(-3_000, battery: 42)])
        let reading = HistoryHover.reading(at: at(-3_000), in: d)

        XCTAssertEqual(reading.anchor, at(-3_000))
        XCTAssertEqual(reading.content, .reading(percent: 42, power: .on, outage: nil))
    }

    // MARK: - Huecos

    func testGapBetweenSegmentsIsNoData() {
        // 90 min entre muestras > umbral de 25 min → dos segmentos con un hueco en medio.
        let d = data([sample(-7_200, battery: 90), sample(-1_800, battery: 70)])
        let cursor = at(-4_500)
        let reading = HistoryHover.reading(at: cursor, in: d)

        XCTAssertEqual(reading.anchor, cursor, "en un hueco la línea sigue al cursor, no a una muestra")
        XCTAssertEqual(reading.content, .noData)
    }

    func testBeforeFirstSampleIsNoData() {
        let d = data([sample(-3_000, battery: 90), sample(-2_400, battery: 85)])
        let cursor = at(-10_000)
        let reading = HistoryHover.reading(at: cursor, in: d)

        XCTAssertEqual(reading.anchor, cursor)
        XCTAssertEqual(reading.content, .noData)
    }

    func testAfterLastSampleIsNoData() {
        let d = data([sample(-3_000, battery: 90), sample(-2_400, battery: 85)])
        let cursor = at(-600)
        let reading = HistoryHover.reading(at: cursor, in: d)

        XCTAssertEqual(reading.anchor, cursor)
        XCTAssertEqual(reading.content, .noData)
    }

    func testEmptyDataIsNoData() {
        let reading = HistoryHover.reading(at: at(-3_000), in: data([]))

        XCTAssertEqual(reading.content, .noData)
    }

    // MARK: - Cortes

    func testOngoingOutageReachesEndOfDomain() {
        let samples = stride(from: -3_600.0, through: -600.0, by: 600).map {
            sample($0, battery: 80, power: .off)
        }
        let reading = HistoryHover.reading(at: at(-1_800), in: data(samples))

        guard case let .reading(_, power, outage) = reading.content else {
            return XCTFail("se esperaba una lectura, no \(reading.content)")
        }
        XCTAssertEqual(power, .off)
        XCTAssertEqual(outage?.start, at(-3_600))
        XCTAssertEqual(outage?.end, now)
        XCTAssertEqual(outage?.isOngoing, true)
    }

    func testClosedOutageEndsAtFirstPoweredSample() {
        // Sin electricidad de -7200 a -3600; la corriente vuelve en la muestra de -3000.
        let off = stride(from: -7_200.0, through: -3_600.0, by: 600).map {
            sample($0, battery: 80, power: .off)
        }
        let on = stride(from: -3_000.0, through: -600.0, by: 600).map {
            sample($0, battery: 85, power: .on)
        }
        let reading = HistoryHover.reading(at: at(-4_400), in: data(off + on))

        guard case let .reading(_, power, outage) = reading.content else {
            return XCTFail("se esperaba una lectura, no \(reading.content)")
        }
        XCTAssertEqual(reading.anchor, at(-4_200))
        XCTAssertEqual(power, .off)
        XCTAssertEqual(outage?.start, at(-7_200))
        XCTAssertEqual(outage?.end, at(-3_000))
        XCTAssertEqual(outage?.isOngoing, false)
        XCTAssertEqual(outage?.duration, 4_200)
    }

    func testStaleOutageIsClampedToTheLastRecordedSample() {
        // El registro se corta hace 3 h (app cerrada). El corte no puede declararse
        // "en curso" ni acumular las horas que nadie midió.
        let samples = stride(from: -18_000.0, through: -10_800.0, by: 600).map {
            sample($0, battery: 40, power: .off)
        }
        let reading = HistoryHover.reading(at: at(-14_400), in: data(samples))

        guard case let .reading(_, _, outage) = reading.content else {
            return XCTFail("se esperaba una lectura, no \(reading.content)")
        }
        XCTAssertEqual(outage?.start, at(-18_000))
        XCTAssertEqual(outage?.end, at(-10_800), "el tramo se recorta a la última muestra real")
        XCTAssertEqual(outage?.isOngoing, false)
        XCTAssertEqual(outage?.duration, 7_200)
    }

    func testPoweredSampleHasNoOutage() {
        let off = stride(from: -7_200.0, through: -3_600.0, by: 600).map {
            sample($0, battery: 80, power: .off)
        }
        let on = stride(from: -3_000.0, through: -600.0, by: 600).map {
            sample($0, battery: 85, power: .on)
        }
        let reading = HistoryHover.reading(at: at(-1_800), in: data(off + on))

        guard case let .reading(_, power, outage) = reading.content else {
            return XCTFail("se esperaba una lectura, no \(reading.content)")
        }
        XCTAssertEqual(power, .on)
        XCTAssertNil(outage)
    }
}
