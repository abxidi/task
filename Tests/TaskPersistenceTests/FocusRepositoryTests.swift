import SwiftData
import XCTest
import TaskDomain
@testable import TaskPersistence

@MainActor
final class FocusRepositoryTests: XCTestCase {
    func testUpsertingFocusEntryLeavesTaskWorkflowUntouched() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "准备演示")
        container.mainContext.insert(task)
        try container.mainContext.save()
        let repository = FocusRepository(context: container.mainContext)

        let entry = try repository.upsert(task: task, state: .focused, note: "先确认讲稿")

        XCTAssertEqual(entry.task?.id, task.id)
        XCTAssertEqual(entry.state, .focused)
        XCTAssertEqual(entry.note, "先确认讲稿")
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.boardColumn)
    }

    func testUpsertingTheSameTaskKeepsOneFocusEntry() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "准备演示")
        container.mainContext.insert(task)
        try container.mainContext.save()
        let repository = FocusRepository(context: container.mainContext)

        let first = try repository.upsert(task: task, state: .focused, note: "第一条")
        let second = try repository.upsert(task: task, state: .blocked, note: "等待输入")

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try repository.fetchEntries().count, 1)
        XCTAssertEqual(second.state, .blocked)
        XCTAssertEqual(second.note, "等待输入")
    }

    func testUpdatingFocusEntryKeepsTaskWorkflowUntouched() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "等待反馈")
        task.isCompleted = true
        task.urgency = 3
        container.mainContext.insert(task)
        try container.mainContext.save()
        let repository = FocusRepository(context: container.mainContext)

        _ = try repository.upsert(task: task, state: .focused, note: "初始备注")
        let entry = try repository.upsert(task: task, state: .waiting, note: "等待确认")

        XCTAssertEqual(entry.state, .waiting)
        XCTAssertEqual(entry.note, "等待确认")
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.urgency, 3)
    }

    func testMigratingLegacyPausedStateWritesWaitingRawValue() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "等待评审")
        let entry = FocusEntry(state: .focused)
        entry.stateRawValue = "paused"
        entry.task = task
        task.focusEntry = entry
        container.mainContext.insert(task)
        container.mainContext.insert(entry)
        try container.mainContext.save()

        XCTAssertEqual(entry.state, .waiting)
        let migratedCount = try FocusRepository(context: container.mainContext).migrateLegacyStates()

        XCTAssertEqual(migratedCount, 1)
        XCTAssertEqual(entry.stateRawValue, "waiting")
        XCTAssertEqual(entry.state, .waiting)
        XCTAssertEqual(try FocusRepository(context: container.mainContext).migrateLegacyStates(), 0)
    }
}
