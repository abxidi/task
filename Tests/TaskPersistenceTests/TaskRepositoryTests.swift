import Foundation
import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class TaskRepositoryTests: XCTestCase {
    func testNewTaskUsesApprovedDefaults() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)

        let item = try repository.createTask(title: "Draft launch plan")

        XCTAssertEqual(item.urgency, 0)
        XCTAssertEqual(item.importance, 0)
        XCTAssertNil(item.project)
        XCTAssertNil(item.boardColumn)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.dueAt)
    }

    func testRejectsOutOfRangeCoordinatesBeforeSave() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.createTask(title: "Invalid")
        XCTAssertThrowsError(try repository.updatePriority(item, urgency: 4, importance: 0))
    }
}
