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
    }
}
