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

    func testStartTimeCannotBeLaterThanEndTime() {
        let start = Date(timeIntervalSince1970: 200)
        let end = Date(timeIntervalSince1970: 100)

        XCTAssertThrowsError(
            try TaskDraft(title: "时间冲突", startAt: start, dueAt: end).validated()
        ) { error in
            XCTAssertEqual(error as? TaskDraftError, .invalidTimeRange)
        }
    }

    func testValidatedSubtasksPreserveTheUserDefinedOrder() throws {
        let draft = TaskDraft(
            title: "Plan",
            subtasks: ["已完成一", "未完成一", "已完成二", "未完成二"],
            subtaskCompletion: [true, false, true, false]
        )
        XCTAssertEqual(try draft.validated().subtasks, ["已完成一", "未完成一", "已完成二", "未完成二"])
        XCTAssertEqual(try draft.validated().subtaskCompletion, [true, false, true, false])
    }

    func testTogglingSubtaskPreservesItsPosition() {
        var draft = TaskDraft(
            title: "Plan",
            subtasks: ["当前", "待办", "已完成"],
            subtaskCompletion: [false, false, true]
        )

        draft.toggleSubtaskCompletion(at: 0)
        XCTAssertEqual(draft.subtasks, ["当前", "待办", "已完成"])
        XCTAssertEqual(draft.subtaskCompletion, [true, false, true])

        draft.toggleSubtaskCompletion(at: 1)
        XCTAssertEqual(draft.subtasks, ["当前", "待办", "已完成"])
        XCTAssertEqual(draft.subtaskCompletion, [true, true, true])
    }

    func testAddingSubtaskAppendsAfterTheLastExistingItem() {
        var draft = TaskDraft(
            title: "Plan",
            subtasks: ["待办", "已完成"],
            subtaskCompletion: [false, true]
        )

        draft.addSubtask("新增")

        XCTAssertEqual(draft.subtasks, ["待办", "已完成", "新增"])
        XCTAssertEqual(draft.subtaskCompletion, [false, true, false])
    }

    func testSubtaskIdentityMovesWithTheSubtask() {
        let firstID = UUID()
        let secondID = UUID()
        var draft = TaskDraft(
            title: "Plan",
            subtasks: ["第一项", "第二项"],
            subtaskCompletion: [false, false],
            subtaskIDs: [firstID, secondID]
        )

        draft.toggleSubtaskCompletion(at: 0)

        XCTAssertEqual(draft.subtasks, ["第一项", "第二项"])
        XCTAssertEqual(draft.subtaskIDs, [firstID, secondID])
    }
}
