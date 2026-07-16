import Foundation
import XCTest
@testable import TaskApp

final class BoardDragPresentationTests: XCTestCase {
    func testMotionContractUsesShortEaseOutDurations() {
        XCTAssertEqual(BoardDragPresentation.liftDuration, 0.14)
        XCTAssertEqual(BoardDragPresentation.dropDuration, 0.18)
        XCTAssertEqual(BoardDragPresentation.liftedScale, 1.015)
        XCTAssertEqual(BoardDragPresentation.targetGhostOpacity, 0.28)
        XCTAssertEqual(BoardDragPresentation.targetTintOpacity, 0.12)
    }

    func testSuccessfulDropHandoffDisablesFollowUpAnimations() {
        let transaction = BoardDragPresentation.handoffTransaction

        XCTAssertNil(transaction.animation)
        XCTAssertTrue(transaction.disablesAnimations)
    }

    func testActiveSourceUsesPlaceholderOpacityInsteadOfBeingHidden() {
        XCTAssertEqual(
            BoardDragPresentation.sourceOpacity(isActiveSource: true),
            0.35
        )
        XCTAssertEqual(BoardDragPresentation.sourceOpacity(isActiveSource: false), 1)
    }

    func testPlaceholderIndexIsClampedToLaneBounds() {
        XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: -1, taskCount: 2), 0)
        XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: 1, taskCount: 2), 1)
        XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: 9, taskCount: 2), 2)
    }

    func testInsertionIndexUsesTheFinalSortedPosition() {
        XCTAssertEqual(
            BoardDragPresentation.insertionIndex(
                itemID: "dragged",
                sortedIDs: ["first", "dragged", "last"]
            ),
            1
        )
        XCTAssertNil(
            BoardDragPresentation.insertionIndex(
                itemID: "missing",
                sortedIDs: ["first", "last"]
            )
        )
    }

    func testSourceLaneDoesNotRenderASecondPlaceholder() {
        let sourceColumnID = UUID()

        XCTAssertFalse(
            BoardDragPresentation.showsTargetPlaceholder(
                sourceColumnID: sourceColumnID,
                targetColumnID: sourceColumnID
            )
        )
        XCTAssertTrue(
            BoardDragPresentation.showsTargetPlaceholder(
                sourceColumnID: sourceColumnID,
                targetColumnID: UUID()
            )
        )
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
    func testSettlementRetainsSessionAtDestinationUntilCompletion() {
        let taskID = UUID()
        let sourceColumnID = UUID()
        let sourceFrame = CGRect(x: 40, y: 50, width: 228, height: 92)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(
            taskID: taskID,
            sourceColumnID: sourceColumnID,
            boardLocation: CGPoint(x: 100, y: 80),
            sourceFrame: sourceFrame,
            grabOffset: CGPoint(x: 30, y: 20)
        )
        coordinator.settle(to: CGRect(x: 420, y: 160, width: 228, height: 92))

        XCTAssertEqual(coordinator.session?.phase, .settling)
        XCTAssertEqual(coordinator.boardLocation, CGPoint(x: 450, y: 180))
        XCTAssertEqual(coordinator.session?.sourceFrame, sourceFrame)

        coordinator.complete()

        XCTAssertNil(coordinator.session)
    }

    @MainActor
    func testPointerUpdatesAreIgnoredWhileSettling() {
        let coordinator = BoardDragCoordinator()
        let targetColumnID = UUID()

        coordinator.begin(
            taskID: UUID(),
            sourceColumnID: UUID(),
            boardLocation: CGPoint(x: 100, y: 80),
            sourceFrame: CGRect(x: 40, y: 50, width: 228, height: 92),
            grabOffset: CGPoint(x: 30, y: 20)
        )
        coordinator.settle(to: CGRect(x: 420, y: 160, width: 228, height: 92))
        coordinator.update(boardLocation: CGPoint(x: 900, y: 700), targetColumnID: targetColumnID)

        XCTAssertEqual(coordinator.boardLocation, CGPoint(x: 450, y: 180))
        XCTAssertNotEqual(coordinator.targetColumnID, targetColumnID)
    }

    @MainActor
    func testSettlingCanRetargetToSourceAfterFailedMove() {
        let sourceFrame = CGRect(x: 40, y: 50, width: 228, height: 92)
        let coordinator = BoardDragCoordinator()

        coordinator.begin(
            taskID: UUID(),
            sourceColumnID: UUID(),
            boardLocation: CGPoint(x: 100, y: 80),
            sourceFrame: sourceFrame,
            grabOffset: CGPoint(x: 30, y: 20)
        )
        coordinator.settle(to: CGRect(x: 420, y: 160, width: 228, height: 92))
        coordinator.settle(to: sourceFrame)

        XCTAssertEqual(coordinator.session?.phase, .settling)
        XCTAssertEqual(coordinator.boardLocation, CGPoint(x: 70, y: 70))
    }

    @MainActor
    func testAtomicHandoffClearsSessionOnlyAfterSuccessfulMove() {
        let coordinator = BoardDragCoordinator()
        coordinator.begin(taskID: UUID(), sourceColumnID: UUID(), boardLocation: .zero)

        XCTAssertFalse(
            BoardDragPresentation.completeHandoff(coordinator: coordinator) { false }
        )
        XCTAssertNotNil(coordinator.session)

        XCTAssertTrue(
            BoardDragPresentation.completeHandoff(coordinator: coordinator) { true }
        )
        XCTAssertNil(coordinator.session)
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
