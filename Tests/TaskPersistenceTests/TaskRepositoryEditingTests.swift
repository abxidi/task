import SwiftData
import XCTest
import TaskDomain
@testable import TaskPersistence

@MainActor
final class TaskRepositoryEditingTests: XCTestCase {
    func testSaveDraftPersistsDescriptionPriorityAndSubtasks() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let draft = TaskDraft(
            title: "Launch",
            details: "Context",
            coordinate: .init(uncheckedUrgency: 3, importance: 3),
            subtasks: ["Price", "Channels"],
            subtaskCompletion: [true, false]
        )
        let item = try repository.saveNewTask(draft)
        XCTAssertEqual(item.details, "Context")
        XCTAssertEqual(item.urgency, 3)
        XCTAssertEqual(item.importance, 3)
        XCTAssertEqual(item.subtasks.sorted { $0.order < $1.order }.map(\.title), ["Channels", "Price"])
        XCTAssertEqual(item.subtasks.sorted { $0.order < $1.order }.map(\.isCompleted), [false, true])
    }

    func testUpdatingSubtaskKeepsItsExistingAttachment() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(TaskDraft(title: "演示", subtasks: ["原始子任务"]))
        let subtask = try XCTUnwrap(item.subtasks.first)
        let attachment = SubtaskAttachment(imageData: Data([0x01]), thumbnailData: Data([0x02]))
        attachment.subtask = subtask
        container.mainContext.insert(attachment)
        try container.mainContext.save()

        var draft = TaskDraft(
            title: item.title,
            subtasks: ["已修改子任务"],
            subtaskIDs: [subtask.id]
        )
        draft.subtaskCompletion = [false]
        try repository.updateTask(item, with: draft)

        let updated = try XCTUnwrap(item.subtasks.first)
        XCTAssertEqual(updated.id, subtask.id)
        XCTAssertEqual(updated.title, "已修改子任务")
        XCTAssertEqual(updated.attachments.first?.id, attachment.id)
    }

    func testUpdatingSubtaskTitleTrimsAndPersistsTheNewTitle() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(TaskDraft(title: "正在做", subtasks: ["原始内容"]))
        let subtask = try XCTUnwrap(item.subtasks.first)

        try repository.updateSubtaskTitle(subtask, title: "  已修改内容  ")

        XCTAssertEqual(subtask.title, "已修改内容")
        XCTAssertEqual(item.subtasks.first?.title, "已修改内容")
    }

    func testMovingAnIncompleteSubtaskPersistsItsNewManualOrder() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(
            TaskDraft(
                title: "正在做",
                subtasks: ["先做", "中间", "后做", "已完成"],
                subtaskCompletion: [false, false, false, true]
            )
        )
        let middle = try XCTUnwrap(item.subtasks.first { $0.title == "中间" })
        let after = try XCTUnwrap(item.subtasks.first { $0.title == "后做" })

        try repository.moveSubtask(middle, after: after)

        let ordered = item.subtasks.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.title), ["先做", "后做", "中间", "已完成"])
        XCTAssertEqual(ordered.map(\.isCompleted), [false, false, false, true])
    }

    func testMovingAnIncompleteSubtaskKeepsCompletedItemsAtTheEnd() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(
            TaskDraft(
                title: "正在做",
                subtasks: ["第一项", "已完成", "第二项", "第三项"],
                subtaskCompletion: [false, true, false, false]
            )
        )
        let second = try XCTUnwrap(item.subtasks.first { $0.title == "第二项" })
        let third = try XCTUnwrap(item.subtasks.first { $0.title == "第三项" })

        try repository.moveSubtask(second, after: third)

        let ordered = item.subtasks.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.title), ["第一项", "第三项", "第二项", "已完成"])
        XCTAssertEqual(ordered.map(\.isCompleted), [false, false, false, true])
    }

    func testMovingAnEarlierSubtaskBeforeALaterSubtaskKeepsTheTargetPosition() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(TaskDraft(title: "正在做", subtasks: ["第一项", "第二项", "第三项"]))
        let first = try XCTUnwrap(item.subtasks.first { $0.title == "第一项" })
        let third = try XCTUnwrap(item.subtasks.first { $0.title == "第三项" })

        try repository.moveSubtask(first, before: third)

        XCTAssertEqual(item.subtasks.sorted { $0.order < $1.order }.map(\.title), ["第二项", "第一项", "第三项"])
    }

    func testSettingSubtaskCompletedPreservesItsManualOrder() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(TaskDraft(title: "正在做", subtasks: ["先做", "后做"]))
        let first = try XCTUnwrap(item.subtasks.first { $0.title == "先做" })

        try repository.setSubtaskCompleted(first, isCompleted: true)

        let ordered = item.subtasks.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.title), ["先做", "后做"])
        XCTAssertEqual(ordered.map(\.isCompleted), [true, false])
    }

    func testCompletingSubtaskClearsItsFocusData() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = try TaskRepository(context: container.mainContext)
            .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归"]))
        let subtask = try XCTUnwrap(task.subtasks.first)
        try FocusRepository(context: container.mainContext).start(subtask)

        try TaskRepository(context: container.mainContext).setSubtaskCompleted(subtask, isCompleted: true)

        XCTAssertNil(subtask.focusState)
        XCTAssertNil(subtask.focusNote)
        XCTAssertNil(subtask.focusUpdatedAt)
    }

    func testAddingSubtaskAppendsAfterTheLastExistingItem() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.saveNewTask(
            TaskDraft(
                title: "正在做",
                subtasks: ["未完成", "已完成"],
                subtaskCompletion: [false, true]
            )
        )

        _ = try repository.addSubtask(to: item, title: "新增子任务")

        let ordered = item.subtasks.sorted { $0.order < $1.order }
        XCTAssertEqual(ordered.map(\.title), ["未完成", "已完成", "新增子任务"])
        XCTAssertEqual(ordered.map(\.isCompleted), [false, true, false])
    }
}
