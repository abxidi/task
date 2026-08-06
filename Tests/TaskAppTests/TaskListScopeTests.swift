import XCTest
@testable import TaskApp
import TaskPersistence

final class TaskListScopeTests: XCTestCase {
    func testScopesUseAllTasks() {
        XCTAssertEqual(
            TaskListScope.allCases.map(\.title),
            ["今天", "本周", "全部任务", "已完成"]
        )
    }

    func testCompletedScopeAllowsTaskDeletionOnly() {
        XCTAssertTrue(TaskListScope.completed.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.today.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.thisWeek.allowsTaskDeletion)
        XCTAssertFalse(TaskListScope.all.allowsTaskDeletion)
    }

    func testThisWeekIncludesOnlyDatesInTheCurrentCalendarWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = date("2026-08-06T12:00:00Z")

        XCTAssertTrue(TaskListDateFilter.matches(
            dueAt: date("2026-08-03T00:00:00Z"),
            in: .thisWeek,
            now: now,
            calendar: calendar
        ))
        XCTAssertTrue(TaskListDateFilter.matches(
            dueAt: date("2026-08-09T23:59:59Z"),
            in: .thisWeek,
            now: now,
            calendar: calendar
        ))
        XCTAssertFalse(TaskListDateFilter.matches(
            dueAt: date("2026-08-02T23:59:59Z"),
            in: .thisWeek,
            now: now,
            calendar: calendar
        ))
        XCTAssertFalse(TaskListDateFilter.matches(
            dueAt: date("2026-08-10T00:00:00Z"),
            in: .thisWeek,
            now: now,
            calendar: calendar
        ))
    }

    func testCompletionLaneAllowsTaskDeletionInAllTasksScope() {
        let completionLane = BoardColumn(name: "已完成", order: 3, isCompletionColumn: true)
        let planningLane = BoardColumn(name: "待规划", order: 0)

        XCTAssertTrue(TaskListScope.all.allowsTaskDeletion(in: completionLane))
        XCTAssertFalse(TaskListScope.all.allowsTaskDeletion(in: planningLane))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
