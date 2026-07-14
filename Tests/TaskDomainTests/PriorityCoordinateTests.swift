import XCTest
@testable import TaskDomain

final class PriorityCoordinateTests: XCTestCase {
    func testAcceptsEveryValueInApprovedRange() throws {
        for urgency in -3...3 {
            for importance in -3...3 {
                XCTAssertEqual(
                    try PriorityCoordinate(urgency: urgency, importance: importance),
                    PriorityCoordinate(uncheckedUrgency: urgency, importance: importance)
                )
            }
        }
    }

    func testRejectsValuesOutsideApprovedRange() {
        XCTAssertThrowsError(try PriorityCoordinate(urgency: -4, importance: 0))
        XCTAssertThrowsError(try PriorityCoordinate(urgency: 0, importance: 4))
    }

    func testQuadrantsAndZeroAxes() throws {
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: 3).quadrant, .actNow)
        XCTAssertEqual(try PriorityCoordinate(urgency: -3, importance: 3).quadrant, .plan)
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: -3).quadrant, .delegate)
        XCTAssertEqual(try PriorityCoordinate(urgency: -3, importance: -3).quadrant, .defer)
        XCTAssertEqual(try PriorityCoordinate(urgency: 0, importance: 3).quadrant, .undecided)
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: 0).quadrant, .undecided)
        XCTAssertEqual(try PriorityCoordinate(urgency: 0, importance: 0).quadrant, .undecided)
    }

    func testClampingForDragInput() {
        XCTAssertEqual(PriorityCoordinate.clamped(urgency: 8, importance: -9), .init(uncheckedUrgency: 3, importance: -3))
    }
}
