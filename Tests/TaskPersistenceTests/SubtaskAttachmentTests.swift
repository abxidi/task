import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class SubtaskAttachmentTests: XCTestCase {
    func testAttachmentIsOwnedByItsSubtask() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "整理材料")
        let subtask = Subtask(title: "粘贴图片", order: 0)
        let attachment = SubtaskAttachment(
            imageData: Data([0x01, 0x02, 0x03]),
            thumbnailData: Data([0x04])
        )
        subtask.task = task
        attachment.subtask = subtask
        container.mainContext.insert(task)
        container.mainContext.insert(subtask)
        container.mainContext.insert(attachment)

        try container.mainContext.save()

        XCTAssertEqual(subtask.attachments.count, 1)
        XCTAssertEqual(subtask.attachments.first?.id, attachment.id)
        XCTAssertEqual(subtask.attachments.first?.imageData, Data([0x01, 0x02, 0x03]))
    }

    func testRepositoryAddsAndRemovesAttachmentForAnExistingSubtask() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "整理材料")
        let subtask = Subtask(title: "粘贴图片", order: 0)
        subtask.task = task
        container.mainContext.insert(task)
        container.mainContext.insert(subtask)
        try container.mainContext.save()
        let repository = SubtaskAttachmentRepository(context: container.mainContext)

        let attachment = try repository.add(
            imageData: Data([0x01, 0x02, 0x03]),
            thumbnailData: Data([0x04]),
            to: subtask
        )
        XCTAssertEqual(subtask.attachments.map(\.id), [attachment.id])

        try repository.remove(attachment)
        XCTAssertTrue(subtask.attachments.isEmpty)
    }
}
