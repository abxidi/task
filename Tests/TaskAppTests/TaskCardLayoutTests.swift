import XCTest
@testable import TaskApp

final class TaskCardLayoutTests: XCTestCase {
    func testPriorityBadgeReservesSpaceAtCardCorner() {
        XCTAssertEqual(TaskCardLayout.priorityBadgeInset, 10)
        XCTAssertGreaterThanOrEqual(TaskCardLayout.titleTrailingReservation, 32)
    }

    func testDeletionActionUsesTheOppositeCardCornerFromPriority() {
        XCTAssertEqual(TaskCardLayout.deletionActionAlignment, .bottomTrailing)
    }

    func testSubtaskProgressShowsIncompleteCountBeforeTotal() {
        XCTAssertEqual(TaskSubtaskProgress.label(for: [false, false, true]), "2/3")
        XCTAssertNil(TaskSubtaskProgress.label(for: []))
    }
}
