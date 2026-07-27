import XCTest
@testable import TaskApp

final class TaskListScopeTests: XCTestCase {
    func testScopesUseAllTasks() {
        XCTAssertEqual(
            TaskListScope.allCases.map(\.title),
            ["今天", "未来 7 天", "全部任务", "已完成"]
        )
    }

    func testCompletedScopeAllowsTaskDeletionOnly() {
        XCTAssertTrue(TaskListScope.completed.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.today.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.nextSevenDays.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.all.allowsTaskDeletion)
    }
}
