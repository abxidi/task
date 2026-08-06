import XCTest
import TaskPersistence
@testable import TaskApp

final class CompletedTaskPresentationTests: XCTestCase {
    func testCompletedTasksDefaultToNewestCompletionTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        let newest = completedTask(title: "最新完成", createdAt: now, completedAt: now.addingTimeInterval(200))
        let oldest = completedTask(title: "较早完成", createdAt: now.addingTimeInterval(100), completedAt: now.addingTimeInterval(50))

        XCTAssertEqual(
            [oldest, newest]
                .sorted(by: CompletedTaskPresentation.sortsByCompletionTime)
                .map(\.title),
            ["最新完成", "较早完成"]
        )
    }

    func testCompletedTasksCanSortByNewestCreationTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        let newest = completedTask(title: "新建较晚", createdAt: now.addingTimeInterval(200), completedAt: now)
        let oldest = completedTask(title: "新建较早", createdAt: now, completedAt: now.addingTimeInterval(200))

        XCTAssertEqual(
            [newest, oldest]
                .sorted(by: CompletedTaskPresentation.sortsByCreationTime)
                .map(\.title),
            ["新建较晚", "新建较早"]
        )
    }

    func testCompletedTaskSearchMatchesTitleDetailsAndTags() {
        let task = completedTask(title: "整理访谈纪要", createdAt: .now, completedAt: .now)
        task.details = "发送给产品团队"
        task.tags = [Tag(name: "客户")]

        XCTAssertTrue(CompletedTaskPresentation.matches(task, query: "访谈"))
        XCTAssertTrue(CompletedTaskPresentation.matches(task, query: "产品"))
        XCTAssertTrue(CompletedTaskPresentation.matches(task, query: "客户"))
        XCTAssertFalse(CompletedTaskPresentation.matches(task, query: "招聘"))
    }

    func testCompletedPresentationDoesNotUseLanes() {
        XCTAssertFalse(CompletedTaskPresentation.showsLanes)
    }

    private func completedTask(title: String, createdAt: Date, completedAt: Date) -> TaskItem {
        let task = TaskItem(title: title, now: createdAt)
        task.isCompleted = true
        task.completedAt = completedAt
        return task
    }
}
