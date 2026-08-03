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
}
