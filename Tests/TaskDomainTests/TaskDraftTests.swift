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

    func testSubtasksPreserveOrder() throws {
        let draft = TaskDraft(title: "Plan", subtasks: ["Second", "First"])
        XCTAssertEqual(try draft.validated().subtasks, ["Second", "First"])
    }
}
