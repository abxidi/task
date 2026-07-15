import XCTest
import TaskPersistence
@testable import TaskApp

final class PriorityMapFilterTests: XCTestCase {
    func testTagFilterKeepsTasksMatchingAnySelectedTag() {
        let urgent = TaskItem(title: "紧急")
        urgent.tags = [Tag(name: "重要")]
        let followUp = TaskItem(title: "跟进")
        followUp.tags = [Tag(name: "待跟进")]
        let unrelated = TaskItem(title: "无标签")

        let result = PriorityMapTaskFilter.tasks(
            from: [urgent, followUp, unrelated],
            scope: .all,
            selectedTagNames: ["重要", "待跟进"]
        )

        XCTAssertEqual(result.map(\.id), [urgent.id, followUp.id])
    }

    func testBuiltInTagsCoverWorkflowsShownInTheEditor() {
        XCTAssertEqual(TaskTagDefaults.names, ["工作", "个人", "重要", "待跟进"])
    }
}
