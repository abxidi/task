import Foundation
import XCTest
@testable import TaskApp

final class BoardDragPresentationTests: XCTestCase {
    func testOnlyActiveDragSourceIsVisuallyHidden() {
        let draggedID = UUID()

        XCTAssertEqual(
            BoardDragPresentation.sourceOpacity(for: draggedID, draggingTaskID: draggedID),
            BoardDragPresentation.hiddenSourceOpacity
        )
        XCTAssertEqual(BoardDragPresentation.sourceOpacity(for: UUID(), draggingTaskID: draggedID), 1)
        XCTAssertEqual(BoardDragPresentation.sourceOpacity(for: draggedID, draggingTaskID: nil), 1)
    }

    @MainActor
    func testBeginInitializesTargetAndLocation() {
        let sourceLaneID = UUID()
        let taskID = UUID()
        let location = CGPoint(x: 24, y: 36)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, location: location)

        XCTAssertEqual(coordinator.taskID, taskID)
        XCTAssertEqual(coordinator.sourceColumnID, sourceLaneID)
        XCTAssertEqual(coordinator.targetColumnID, sourceLaneID)
        XCTAssertEqual(coordinator.location, location)
    }

    @MainActor
    func testUpdateChangesTargetAndLocation() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let location = CGPoint(x: 120, y: 80)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, location: .zero)
        coordinator.update(location: location, targetColumnID: targetLaneID)

        XCTAssertEqual(coordinator.targetColumnID, targetLaneID)
        XCTAssertEqual(coordinator.location, location)
    }

    @MainActor
    func testFinishingDragMovesOnlyToAnotherLaneAndClearsSession() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, location: .zero)
        coordinator.update(location: CGPoint(x: 120, y: 80), targetColumnID: targetLaneID)

        XCTAssertEqual(coordinator.finish(), BoardDragMove(taskID: taskID, targetColumnID: targetLaneID))
        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.targetColumnID)

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, location: .zero)
        coordinator.update(location: CGPoint(x: 80, y: 80), targetColumnID: sourceLaneID)

        XCTAssertNil(coordinator.finish())
        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.sourceColumnID)
        XCTAssertNil(coordinator.targetColumnID)
        XCTAssertNil(coordinator.location)
    }

    @MainActor
    func testCancelClearsAllDragSessionState() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, location: .zero)
        coordinator.update(location: CGPoint(x: 120, y: 80), targetColumnID: targetLaneID)
        coordinator.cancel()

        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.sourceColumnID)
        XCTAssertNil(coordinator.targetColumnID)
        XCTAssertNil(coordinator.location)
    }
}
