import CoreGraphics
import XCTest
import TaskDomain
import TaskPersistence
@testable import TaskApp

final class PriorityMapLayoutTests: XCTestCase {
    func testPriorityMapKeyboardFocusHasNoSystemFocusRing() {
        XCTAssertFalse(PriorityMapFocusStyle.usesSystemFocusRing)
    }

    func testMapSideUsesRemainingHeightAndCapsLargeCanvases() {
        XCTAssertEqual(PriorityMapScreenLayout.mapSide(for: CGSize(width: 900, height: 380)), 380)
        XCTAssertEqual(PriorityMapScreenLayout.mapSide(for: CGSize(width: 900, height: 900)), 620)
    }

    func testPriorityMapUsesCompactChromeMatchedToTheSquareWidth() {
        XCTAssertEqual(
            PriorityMapScreenLayout.contentMaximumWidth,
            PriorityMapScreenLayout.maximumMapSide
        )
        XCTAssertEqual(PriorityMapScreenLayout.metricHeight, 32)
        XCTAssertEqual(PriorityMapScreenLayout.verticalPadding, 12)
    }

    func testCoordinateSquareLeavesRoomForOutsideQuadrantLabels() {
        let square = PriorityMapLayout.coordinateSquare(in: CGSize(width: 500, height: 500))

        XCTAssertEqual(square.width, square.height)
        XCTAssertGreaterThanOrEqual(square.minY, PriorityMapLayout.zoneLabelBand)
        XCTAssertLessThanOrEqual(square.maxY, 500 - PriorityMapLayout.zoneLabelBand)
    }

    func testGroupsTasksAtTheSameCoordinateIntoOneStack() {
        let first = TaskItem(title: "第一个")
        first.urgency = 2
        first.importance = 3
        let second = TaskItem(title: "第二个")
        second.urgency = 2
        second.importance = 3
        let separate = TaskItem(title: "另一个点位")
        separate.urgency = -1
        separate.importance = 1

        let stacks = PriorityMapTaskStacking.stacks(for: [first, second, separate])

        XCTAssertEqual(stacks.count, 2)
        XCTAssertEqual(
            stacks.first { $0.coordinate == PriorityCoordinate(uncheckedUrgency: 2, importance: 3) }?.tasks.count,
            2
        )
    }
}
