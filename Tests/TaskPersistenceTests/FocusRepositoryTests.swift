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
        XCTAssertEqual(entry.stateRawValue, "")
        XCTAssertEqual(entry.note, "")
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
        XCTAssertEqual(second.stateRawValue, "")
        XCTAssertEqual(second.note, "")
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

        XCTAssertEqual(entry.stateRawValue, "")
        XCTAssertEqual(entry.note, "")
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.urgency, 3)
    }

    func testSubtaskFocusNotePreservesLineBreaks() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = try TaskRepository(context: container.mainContext)
            .saveNewTask(TaskDraft(title: "多行备注", subtasks: ["处理备注"]))
        let subtask = try XCTUnwrap(task.subtasks.first)

        let note = "第一行\n第二行\n第三行"
        try FocusRepository(context: container.mainContext)
            .update(subtask, state: .focused, note: note)

        XCTAssertEqual(subtask.focusNote, note)
    }

    func testStartingAndUpdatingSubtasksKeepsTheirFocusDataIndependent() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = try TaskRepository(context: container.mainContext)
            .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归", "确认接口"]))
        let subtasks = task.subtasks.sorted { $0.order < $1.order }
        let repository = FocusRepository(context: container.mainContext)

        try repository.start(subtasks[0])
        try repository.update(subtasks[0], state: .waiting, note: "等待回归结果")
        try repository.start(subtasks[1])

        XCTAssertEqual(subtasks[0].focusState, .waiting)
        XCTAssertEqual(subtasks[0].focusNote, "等待回归结果")
        XCTAssertEqual(subtasks[1].focusState, .focused)
        XCTAssertEqual(subtasks[1].focusNote, "")
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.boardColumn)
    }

    func testStartingSubtaskClearsLegacyTaskLevelFocusMetadata() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = try TaskRepository(context: container.mainContext)
            .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归"]))
        let entry = try FocusRepository(context: container.mainContext)
            .upsert(task: task, state: .blocked, note: "旧备注")

        try FocusRepository(context: container.mainContext).start(try XCTUnwrap(task.subtasks.first))

        XCTAssertEqual(entry.stateRawValue, "")
        XCTAssertEqual(entry.note, "")
    }

    func testMigratingLegacyTaskMetadataDeletesIt() throws {
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
        XCTAssertEqual(entry.stateRawValue, "")
        XCTAssertEqual(entry.note, "")
        XCTAssertEqual(try FocusRepository(context: container.mainContext).migrateLegacyStates(), 0)
    }
}
