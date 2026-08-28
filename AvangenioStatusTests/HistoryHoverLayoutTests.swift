import XCTest
@testable import AvangenioStatusKit

final class HistoryHoverLayoutTests: XCTestCase {
    private let box = CGSize(width: 120, height: 60)
    private let container = CGSize(width: 500, height: 300)
    private let margin: CGFloat = 12

    private func origin(_ cursor: CGPoint, box: CGSize? = nil, container: CGSize? = nil) -> CGPoint {
        HistoryHoverLayout.readoutOrigin(
            cursor: cursor,
            boxSize: box ?? self.box,
            container: container ?? self.container,
            margin: margin
        )
    }

    func testSitsAboveAndRightOfCursorWhenItFits() {
        let point = origin(CGPoint(x: 200, y: 200))

        XCTAssertEqual(point.x, 212)   // 200 + margen
        XCTAssertEqual(point.y, 128)   // 200 - margen - alto
    }

    func testFlipsLeftAgainstTheRightEdge() {
        let point = origin(CGPoint(x: 480, y: 200))

        XCTAssertEqual(point.x, 348)   // 480 - margen - ancho
        XCTAssertLessThanOrEqual(point.x + box.width, container.width)
    }

    func testFlipsBelowAgainstTheTopEdge() {
        let point = origin(CGPoint(x: 200, y: 10))

        XCTAssertEqual(point.y, 22)    // 10 + margen
        XCTAssertGreaterThanOrEqual(point.y, 0)
    }

    func testFlipsOnBothAxesInTheTopRightCorner() {
        let point = origin(CGPoint(x: 490, y: 5))

        XCTAssertEqual(point.x, 358)
        XCTAssertEqual(point.y, 17)
    }

    func testClampsAgainstTheBottomEdge() {
        let point = origin(CGPoint(x: 200, y: 299))

        XCTAssertLessThanOrEqual(point.y + box.height, container.height)
    }

    func testBoxLargerThanContainerAnchorsAtOrigin() {
        let point = origin(
            CGPoint(x: 40, y: 40),
            box: CGSize(width: 800, height: 400),
            container: container
        )

        XCTAssertEqual(point.x, 0)
        XCTAssertEqual(point.y, 0)
    }

    func testUnmeasuredBoxStaysInsideTheContainer() {
        let point = origin(CGPoint(x: 200, y: 200), box: .zero)

        XCTAssertGreaterThanOrEqual(point.x, 0)
        XCTAssertGreaterThanOrEqual(point.y, 0)
    }
}
