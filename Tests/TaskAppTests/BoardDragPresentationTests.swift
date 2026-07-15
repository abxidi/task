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
}
