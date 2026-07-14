import Foundation
import XCTest
@testable import TaskDomain

final class TaskSortTests: XCTestCase {
    func testPrioritySortUsesImportanceThenUrgencyThenDueDateThenCreation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let values = [
            TaskSortValue(id: "a", urgency: 3, importance: 1, dueAt: nil, createdAt: now),
            TaskSortValue(id: "b", urgency: 1, importance: 3, dueAt: now.addingTimeInterval(100), createdAt: now),
            TaskSortValue(id: "c", urgency: 3, importance: 3, dueAt: now.addingTimeInterval(200), createdAt: now),
        ]
        XCTAssertEqual(values.sorted(by: TaskSort.priority).map(\.id), ["c", "b", "a"])
    }
}
