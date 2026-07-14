import XCTest
@testable import TaskDomain

final class PriorityGridMathTests: XCTestCase {
    func testCoordinateToNormalizedPosition() {
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: -3), 0, accuracy: 0.0001)
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: 0), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: 3), 1, accuracy: 0.0001)
    }

    func testNormalizedPositionSnapsToSevenValues() {
        XCTAssertEqual(PriorityGridMath.value(at: 0), -3)
        XCTAssertEqual(PriorityGridMath.value(at: 0.49), 0)
        XCTAssertEqual(PriorityGridMath.value(at: 0.84), 2)
        XCTAssertEqual(PriorityGridMath.value(at: 1), 3)
    }

    func testClampsPointerOutsidePlot() {
        XCTAssertEqual(PriorityGridMath.value(at: -0.5), -3)
        XCTAssertEqual(PriorityGridMath.value(at: 1.5), 3)
    }
}
