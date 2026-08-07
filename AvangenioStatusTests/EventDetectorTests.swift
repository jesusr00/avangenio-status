import XCTest
@testable import AvangenioStatusKit

final class EventDetectorTests: XCTestCase {
    private let detector = EventDetector()
    private let settings = AppSettings(batteryThreshold: 30, bandwidthThresholdMbps: 1.0)

    // AE1: transición de electricidad emite una vez, no se repite.
    func testPowerTransitionEmitsOnce() {
        let previous = status(power: .on)
        let current = status(power: .off)
        let first = detector.detect(previous: previous, current: current, settings: settings, arming: ArmingState())
        XCTAssertEqual(first.events, [.powerChanged(to: .off)])

        let second = detector.detect(previous: current, current: status(power: .off), settings: settings, arming: first.arming)
        XCTAssertTrue(second.events.isEmpty)
    }

    func testInternetTransitions() {
        let down = detector.detect(previous: status(internet: .ok), current: status(internet: .down), settings: settings, arming: ArmingState())
        XCTAssertEqual(down.events, [.internetChanged(to: .down)])
        let up = detector.detect(previous: status(internet: .down), current: status(internet: .ok), settings: settings, arming: ArmingState())
        XCTAssertEqual(up.events, [.internetChanged(to: .ok)])
    }

    // AE2: umbral de baterías con re-arme.
    func testBatteryHysteresis() {
        var arming = ArmingState()

        // 32 -> 28: cruza a la baja, dispara.
        var step = detector.detect(previous: status(battery: 32), current: status(battery: 28), settings: settings, arming: arming)
        arming = step.arming
        XCTAssertEqual(step.events, [.batteryBelowThreshold(value: 28, threshold: 30)])

        // 28 -> 27: sigue bajo, sin disparar.
        step = detector.detect(previous: status(battery: 28), current: status(battery: 27), settings: settings, arming: arming)
        arming = step.arming
        XCTAssertTrue(step.events.isEmpty)

        // 27 -> 35: recupera, re-arma sin evento.
        step = detector.detect(previous: status(battery: 27), current: status(battery: 35), settings: settings, arming: arming)
        arming = step.arming
        XCTAssertTrue(step.events.isEmpty)

        // 35 -> 29: cruza de nuevo, dispara.
        step = detector.detect(previous: status(battery: 35), current: status(battery: 29), settings: settings, arming: arming)
        XCTAssertEqual(step.events, [.batteryBelowThreshold(value: 29, threshold: 30)])
    }

    func testBandwidthHysteresis() {
        var arming = ArmingState()
        var step = detector.detect(previous: status(bandwidth: 2), current: status(bandwidth: 0.5), settings: settings, arming: arming)
        arming = step.arming
        XCTAssertEqual(step.events, [.bandwidthBelowThreshold(value: 0.5, threshold: 1.0)])
        step = detector.detect(previous: status(bandwidth: 0.5), current: status(bandwidth: 0.4), settings: settings, arming: arming)
        XCTAssertTrue(step.events.isEmpty)
    }

    func testValueEqualToThresholdDoesNotFire() {
        // Comparación estricta (<): igual al umbral no dispara y queda armado.
        let result = detector.detect(previous: status(battery: 35), current: status(battery: 30), settings: settings, arming: ArmingState())
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertTrue(result.arming.batteryArmed)
    }

    func testBaselineEmitsNoEvents() {
        let result = detector.detect(previous: nil, current: status(power: .off, internet: .down, battery: 10, bandwidth: 0.1), settings: settings, arming: ArmingState())
        XCTAssertTrue(result.events.isEmpty)
        // Al estar por debajo del umbral en la línea base, queda desarmado.
        XCTAssertFalse(result.arming.batteryArmed)
        XCTAssertFalse(result.arming.bandwidthArmed)
    }

    func testNilMetricNoThresholdEvent() {
        let result = detector.detect(previous: status(battery: 50), current: status(battery: nil), settings: settings, arming: ArmingState())
        XCTAssertTrue(result.events.isEmpty)
    }

    func testSimultaneousChanges() {
        let previous = status(power: .on, internet: .ok, battery: 50, bandwidth: 10)
        let current = status(power: .off, internet: .down, battery: 10, bandwidth: 0.2)
        let result = detector.detect(previous: previous, current: current, settings: settings, arming: ArmingState())
        XCTAssertTrue(result.events.contains(.powerChanged(to: .off)))
        XCTAssertTrue(result.events.contains(.internetChanged(to: .down)))
        XCTAssertTrue(result.events.contains(.batteryBelowThreshold(value: 10, threshold: 30)))
        XCTAssertTrue(result.events.contains(.bandwidthBelowThreshold(value: 0.2, threshold: 1.0)))
    }

    // MARK: helper

    private func status(
        power: PowerStatus = .on,
        internet: InternetStatus = .ok,
        battery: Double? = 50,
        bandwidth: Double? = 10
    ) -> ServiceStatus {
        ServiceStatus(lastUpdatedRaw: "x", internet: internet, bandwidthMbps: bandwidth, batteryPercent: battery, power: power, fetchedAt: Date())
    }
}
