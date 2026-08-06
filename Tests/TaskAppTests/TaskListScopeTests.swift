import XCTest
@testable import TaskApp
import TaskPersistence

final class TaskListScopeTests: XCTestCase {
    func testScopesContainOnlyFocusAllAndCompleted() {
        XCTAssertEqual(
            TaskListScope.allCases.map(\.title),
            ["正在做", "全部任务", "已完成"]
        )
    }

    func testCompletedScopeAllowsTaskDeletionOnly() {
        XCTAssertTrue(TaskListScope.completed.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.focus.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.all.allowsTaskDeletion)
    }

    func testCompletionLaneAllowsTaskDeletionInAllTasksScope() {
        let completionLane = BoardColumn(name: "已完成", order: 3, isCompletionColumn: true)
        let planningLane = BoardColumn(name: "待规划", order: 0)

        XCTAssertTrue(TaskListScope.all.allowsTaskDeletion(in: completionLane))
        XCTAssertFalse(TaskListScope.all.allowsTaskDeletion(in: planningLane))
    }
}
