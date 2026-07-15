import XCTest
@testable import TaskDomain

final class TaskDraftTests: XCTestCase {
    func testOnlyTitleIsRequired() throws {
        let draft = TaskDraft(title: "  Draft launch plan  ")
        XCTAssertEqual(try draft.validated().title, "Draft launch plan")
        XCTAssertEqual(try draft.validated().coordinate, .init(uncheckedUrgency: 0, importance: 0))
    }

    func testEmptyTitleIsRejected() {
        XCTAssertThrowsError(try TaskDraft(title: "   ").validated())
    }

    func testValidatedSubtasksPlaceIncompleteItemsBeforeCompletedItems() throws {
        let draft = TaskDraft(
            title: "Plan",
            subtasks: ["已完成一", "未完成一", "已完成二", "未完成二"],
            subtaskCompletion: [true, false, true, false]
        )
        XCTAssertEqual(try draft.validated().subtasks, ["未完成一", "未完成二", "已完成一", "已完成二"])
        XCTAssertEqual(try draft.validated().subtaskCompletion, [false, false, true, true])
    }

    func testTogglingSubtaskMovesCompletedToEndAndReopenedItemToTop() {
        var draft = TaskDraft(
            title: "Plan",
            subtasks: ["当前", "待办", "已完成"],
            subtaskCompletion: [false, false, true]
        )

        draft.toggleSubtaskCompletion(at: 0)
        XCTAssertEqual(draft.subtasks, ["待办", "已完成", "当前"])
        XCTAssertEqual(draft.subtaskCompletion, [false, true, true])

        draft.toggleSubtaskCompletion(at: 1)
        XCTAssertEqual(draft.subtasks, ["已完成", "待办", "当前"])
        XCTAssertEqual(draft.subtaskCompletion, [false, false, true])
    }

    func testAddingSubtaskPlacesItBeforeCompletedItems() {
        var draft = TaskDraft(
            title: "Plan",
            subtasks: ["待办", "已完成"],
            subtaskCompletion: [false, true]
        )

        draft.addSubtask("新增")

        XCTAssertEqual(draft.subtasks, ["待办", "新增", "已完成"])
        XCTAssertEqual(draft.subtaskCompletion, [false, false, true])
    }
}
