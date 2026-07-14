import XCTest
@testable import TaskApp

final class TaskCardLayoutTests: XCTestCase {
    func testPriorityBadgeReservesSpaceAtCardCorner() {
        XCTAssertEqual(TaskCardLayout.priorityBadgeInset, 10)
        XCTAssertGreaterThanOrEqual(TaskCardLayout.titleTrailingReservation, 32)
    }
}
