import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class BoardWorkflowServiceTests: XCTestCase {
    func testNewProjectHasExactlyOneCompletionColumn() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let project = try repository.createProject(name: "Launch", colorHex: "#F07446")
        XCTAssertEqual(project.boardColumns.count, 4)
        XCTAssertEqual(project.boardColumns.filter(\.isCompletionColumn).count, 1)
    }

    func testMoveIntoAndOutOfCompletionColumnMaintainsState() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let project = try repository.createProject(name: "Launch", colorHex: "#F07446")
        let todo = project.boardColumns.sorted { $0.order < $1.order }.first!
        let done = project.boardColumns.first(where: \.isCompletionColumn)!
        let task = TaskItem(title: "Plan")
        task.project = project
        task.boardColumn = todo
        container.mainContext.insert(task)
        _ = try FocusRepository(context: container.mainContext)
            .upsert(task: task, state: .focused, note: "准备发布")
        let service = BoardWorkflowService(context: container.mainContext)

        try service.move(task, to: done, now: Date(timeIntervalSince1970: 500))
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.completedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(task.previousBoardColumnID, todo.id)
        XCTAssertNil(task.focusEntry)
        XCTAssertTrue(try FocusRepository(context: container.mainContext).fetchEntries().isEmpty)

        try service.move(task, to: todo, now: Date(timeIntervalSince1970: 600))
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
    }
}
