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
    func testBeginInitializesTargetAndBoardLocation() {
        let sourceLaneID = UUID()
        let taskID = UUID()
        let boardLocation = CGPoint(x: 24, y: 36)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, boardLocation: boardLocation)

        XCTAssertEqual(coordinator.taskID, taskID)
        XCTAssertEqual(coordinator.sourceColumnID, sourceLaneID)
        XCTAssertEqual(coordinator.targetColumnID, sourceLaneID)
        XCTAssertEqual(coordinator.boardLocation, boardLocation)
        XCTAssertEqual(
            coordinator.session,
            BoardDragSession(
                taskID: taskID,
                sourceColumnID: sourceLaneID,
                targetColumnID: sourceLaneID,
                boardLocation: boardLocation
            )
        )
    }

    @MainActor
    func testUpdateChangesTargetAndBoardLocation() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let boardLocation = CGPoint(x: 120, y: 80)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, boardLocation: .zero)
        coordinator.update(boardLocation: boardLocation, targetColumnID: targetLaneID)

        XCTAssertEqual(coordinator.targetColumnID, targetLaneID)
        XCTAssertEqual(coordinator.boardLocation, boardLocation)
        XCTAssertEqual(
            coordinator.session,
            BoardDragSession(
                taskID: taskID,
                sourceColumnID: sourceLaneID,
                targetColumnID: targetLaneID,
                boardLocation: boardLocation
            )
        )
    }

    @MainActor
    func testFinishingDragMovesOnlyToAnotherLaneAndClearsSession() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, boardLocation: .zero)
        coordinator.update(boardLocation: CGPoint(x: 120, y: 80), targetColumnID: targetLaneID)

        XCTAssertEqual(coordinator.finish(), BoardDragMove(taskID: taskID, targetColumnID: targetLaneID))
        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.sourceColumnID)
        XCTAssertNil(coordinator.targetColumnID)
        XCTAssertNil(coordinator.boardLocation)
        XCTAssertNil(coordinator.session)

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, boardLocation: .zero)
        coordinator.update(boardLocation: CGPoint(x: 80, y: 80), targetColumnID: sourceLaneID)

        XCTAssertNil(coordinator.finish())
        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.sourceColumnID)
        XCTAssertNil(coordinator.targetColumnID)
        XCTAssertNil(coordinator.boardLocation)
        XCTAssertNil(coordinator.session)
    }

    @MainActor
    func testCancelClearsAllDragSessionState() {
        let sourceLaneID = UUID()
        let targetLaneID = UUID()
        let taskID = UUID()
        let coordinator = BoardDragCoordinator()

        coordinator.begin(taskID: taskID, sourceColumnID: sourceLaneID, boardLocation: .zero)
        coordinator.update(boardLocation: CGPoint(x: 120, y: 80), targetColumnID: targetLaneID)
        coordinator.cancel()

        XCTAssertNil(coordinator.taskID)
        XCTAssertNil(coordinator.sourceColumnID)
        XCTAssertNil(coordinator.targetColumnID)
        XCTAssertNil(coordinator.boardLocation)
        XCTAssertNil(coordinator.session)
    }
}
