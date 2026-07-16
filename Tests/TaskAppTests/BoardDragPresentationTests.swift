import Foundation
import XCTest
@testable import TaskApp

final class BoardDragPresentationTests: XCTestCase {
    func testActiveSourceUsesPlaceholderOpacityInsteadOfBeingHidden() {
        XCTAssertEqual(
            BoardDragPresentation.sourceOpacity(isActiveSource: true),
            0.35
        )
        XCTAssertEqual(BoardDragPresentation.sourceOpacity(isActiveSource: false), 1)
    }

    func testOverlayOffsetPreservesGrabPointRelativeToTheCard() {
        let pointerLocation = CGPoint(x: 420, y: 310)
        let grabOffset = CGPoint(x: 68, y: 24)
        let overlayGlobalFrame = CGRect(x: 100, y: 80, width: 800, height: 600)

        XCTAssertEqual(
            BoardDragPresentation.overlayOffset(
                for: pointerLocation,
                grabOffset: grabOffset,
                in: overlayGlobalFrame
            ),
            CGSize(width: 252, height: 206)
        )
    }

    @MainActor
    func testDragSessionRetainsGrabOffsetAndCalculatesItsTopLeadingOverlayPosition() {
        let sourceLaneID = UUID()
        let taskID = UUID()
        let coordinator = BoardDragCoordinator()
        let pointerLocation = CGPoint(x: 420, y: 310)
        let grabOffset = CGPoint(x: 68, y: 24)

        coordinator.begin(
            taskID: taskID,
            sourceColumnID: sourceLaneID,
            boardLocation: pointerLocation,
            grabOffset: grabOffset
        )

        XCTAssertEqual(coordinator.session?.grabOffset, grabOffset)
        XCTAssertEqual(
            BoardDragPresentation.overlayOffset(
                for: coordinator.session!.boardLocation,
                grabOffset: coordinator.session!.grabOffset,
                in: CGRect(x: 100, y: 80, width: 800, height: 600)
            ),
            CGSize(width: 252, height: 206)
        )
    }

    @MainActor
    func testTaskListDragStateExposesOneExternalCoordinatorForAllLanes() {
        let dragState = TaskListBoardDragState()
        let firstLaneCoordinator = dragState.coordinator
        let secondLaneCoordinator = dragState.coordinator

        XCTAssertTrue(firstLaneCoordinator === secondLaneCoordinator)
    }

    func testCompletionDecisionCancelsWhenPointerIsOutsideAnyLane() {
        XCTAssertEqual(
            BoardDragPresentation.completionDecision(
                taskID: UUID(),
                sourceColumnID: UUID(),
                targetColumnID: nil
            ),
            .cancel
        )
    }

    func testCompletionDecisionDoesNotMoveWithinTheSourceLane() {
        let taskID = UUID()
        let sourceColumnID = UUID()

        XCTAssertEqual(
            BoardDragPresentation.completionDecision(
                taskID: taskID,
                sourceColumnID: sourceColumnID,
                targetColumnID: sourceColumnID
            ),
            .noMove
        )
    }

    func testCompletionDecisionProducesOneMoveAcrossLanes() {
        let taskID = UUID()
        let sourceColumnID = UUID()
        let targetColumnID = UUID()

        XCTAssertEqual(
            BoardDragPresentation.completionDecision(
                taskID: taskID,
                sourceColumnID: sourceColumnID,
                targetColumnID: targetColumnID
            ),
            .move(BoardDragMove(taskID: taskID, targetColumnID: targetColumnID))
        )
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
                boardLocation: boardLocation,
                grabOffset: .zero
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
                boardLocation: boardLocation,
                grabOffset: .zero
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
