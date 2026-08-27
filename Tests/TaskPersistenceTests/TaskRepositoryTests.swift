import Foundation
import SwiftData
import XCTest
import TaskDomain
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

    func testCompletingLocalTaskMovesItToLocalCompletionLane() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let lanes = try TaskListLaneRepository(context: container.mainContext).defaultLanes()
        let item = try repository.createTask(title: "完成任务")
        item.boardColumn = lanes[1]
        try container.mainContext.save()
        _ = try FocusRepository(context: container.mainContext)
            .upsert(task: item, state: .focused, note: "收尾")

        try repository.setCompleted(item, isCompleted: true)

        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.boardColumn?.id, lanes[3].id)
        XCTAssertNil(item.focusEntry)
        XCTAssertTrue(try FocusRepository(context: container.mainContext).fetchEntries().isEmpty)
    }

    func testReopeningLocalTaskReturnsItToPreviousLocalLane() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let lanes = try TaskListLaneRepository(context: container.mainContext).defaultLanes()
        let item = try repository.createTask(title: "重新打开任务")
        item.boardColumn = lanes[2]
        try container.mainContext.save()
        _ = try FocusRepository(context: container.mainContext)
            .upsert(task: item, state: .focused, note: "等待确认")
        try repository.setCompleted(item, isCompleted: true)

        try repository.setCompleted(item, isCompleted: false)

        XCTAssertFalse(item.isCompleted)
        XCTAssertEqual(item.boardColumn?.id, lanes[2].id)
        XCTAssertNil(item.previousBoardColumnID)
        XCTAssertNil(item.focusEntry)
        XCTAssertTrue(try FocusRepository(context: container.mainContext).fetchEntries().isEmpty)
    }

    func testSavingAnExistingTaskAsCompletedRemovesItsFocusEntry() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.createTask(title: "编辑完成任务")
        _ = try FocusRepository(context: container.mainContext)
            .upsert(task: item, state: .waiting, note: "等待收尾")
        var draft = TaskDraft(title: item.title)
        draft.isCompleted = true

        try repository.updateTask(item, with: draft)

        XCTAssertTrue(item.isCompleted)
        XCTAssertNil(item.focusEntry)
        XCTAssertTrue(try FocusRepository(context: container.mainContext).fetchEntries().isEmpty)
    }
}
