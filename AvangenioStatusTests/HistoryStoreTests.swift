import XCTest
@testable import AvangenioStatusKit

final class HistoryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func sample(_ t: TimeInterval, battery: Double? = 50, power: PowerStatus = .on) -> EnergySample {
        EnergySample(timestamp: Date(timeIntervalSince1970: t), batteryPercent: battery, power: power)
    }

    func testMissingFileLoadsEmpty() {
        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), [])
    }

    func testAppendThenLoadRoundTrip() {
        let store = HistoryStore(fileURL: fileURL)
        _ = store.append(sample(1000, battery: 62.5, power: .off))
        let reopened = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(reopened.load(), [sample(1000, battery: 62.5, power: .off)])
    }

    func testAppendReturnsSeries() {
        let store = HistoryStore(fileURL: fileURL)
        _ = store.append(sample(1000))
        let result = store.append(sample(2000))
        XCTAssertEqual(result.map(\.timestamp.timeIntervalSince1970), [1000, 2000])
    }

    func testPrunesSamplesOlderThanRetention() {
        let store = HistoryStore(fileURL: fileURL, retention: 100)
        _ = store.append(sample(1000))          // viejo
        let result = store.append(sample(2000)) // corte = 2000 - 100 = 1900 → descarta 1000
        XCTAssertEqual(result.map(\.timestamp.timeIntervalSince1970), [2000])
    }

    func testCorruptFileLoadsEmpty() throws {
        try Data("basura no-json".utf8).write(to: fileURL)
        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), [])
    }
}
