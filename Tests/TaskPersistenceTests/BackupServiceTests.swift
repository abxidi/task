import Foundation
import SwiftData
import XCTest
import TaskDomain
@testable import TaskPersistence

@MainActor
final class BackupServiceTests: XCTestCase {
    func testRoundTripExportImport() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let projectRepo = ProjectRepository(context: container.mainContext)
        let project = try projectRepo.createProject(name: "Launch", colorHex: "#F07446")
        let taskRepo = TaskRepository(context: container.mainContext)
        let task = try taskRepo.createTask(title: "Ship")
        task.project = project
        task.boardColumn = project.boardColumns.sorted { $0.order < $1.order }.first
        task.urgency = 2
        task.importance = 3
        try container.mainContext.save()

        let service = BackupService(context: container.mainContext)
        let data = try service.exportSnapshot(now: Date(timeIntervalSince1970: 9_000))
        let envelope = try service.validateImport(data)

        let importContainer = try ModelContainerFactory.make(inMemory: true)
        let importService = BackupService(context: importContainer.mainContext)
        try importService.applyImport(envelope)

        let importedTasks = try importContainer.mainContext.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(importedTasks.count, 1)
        XCTAssertEqual(importedTasks.first?.title, "Ship")
        XCTAssertEqual(importedTasks.first?.urgency, 2)
        XCTAssertEqual(importedTasks.first?.importance, 3)
    }

    func testRoundTripPreservesStartTimeSubtaskFocusAndImage() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "准备演示")
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        task.startAt = start
        task.dueAt = end
        let subtask = Subtask(title: "检查截图", order: 0)
        subtask.task = task
        let attachment = SubtaskAttachment(imageData: Data([0xA1]), thumbnailData: Data([0xB2]))
        attachment.subtask = subtask
        task.subtasks = [subtask]
        container.mainContext.insert(task)
        container.mainContext.insert(subtask)
        container.mainContext.insert(attachment)
        _ = try FocusRepository(context: container.mainContext).upsert(
            task: task,
            state: .waiting,
            note: "等待评审"
        )
        try FocusRepository(context: container.mainContext)
            .update(subtask, state: .waiting, note: "等待图片确认")

        let service = BackupService(context: container.mainContext)
        let exported = try service.exportSnapshot(now: Date(timeIntervalSince1970: 3_000))
        let envelope = try service.validateImport(exported)
        let restored = try ModelContainerFactory.make(inMemory: true)
        try BackupService(context: restored.mainContext).applyImport(envelope)

        let restoredTask = try XCTUnwrap(try restored.mainContext.fetch(FetchDescriptor<TaskItem>()).first)
        let restoredSubtask = try XCTUnwrap(try restored.mainContext.fetch(FetchDescriptor<Subtask>()).first)
        let restoredFocus = try XCTUnwrap(try restored.mainContext.fetch(FetchDescriptor<FocusEntry>()).first)
        XCTAssertEqual(restoredTask.startAt, start)
        XCTAssertEqual(restoredTask.dueAt, end)
        XCTAssertEqual(restoredSubtask.attachments.first?.imageData, Data([0xA1]))
        XCTAssertEqual(restoredSubtask.focusState, .waiting)
        XCTAssertEqual(restoredSubtask.focusNote, "等待图片确认")
        XCTAssertEqual(restoredFocus.stateRawValue, "")
        XCTAssertEqual(restoredFocus.note, "")
    }

    func testLegacyTaskFocusBackupImportsOnlyTheFocusPoolMembership() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let taskID = UUID()
        let envelope = BackupEnvelope(
            schemaVersion: 2,
            exportedAt: .now,
            projects: [],
            columns: [],
            tasks: [
                BackupTask(
                    id: taskID,
                    title: "等待评审",
                    details: "",
                    urgency: 0,
                    importance: 0,
                    dueAt: nil,
                    reminderAt: nil,
                    estimatedMinutes: nil,
                    isCompleted: false,
                    completedAt: nil,
                    previousBoardColumnID: nil,
                    manualOrder: 0,
                    createdAt: .now,
                    updatedAt: .now,
                    projectID: nil,
                    boardColumnID: nil,
                    tagIDs: []
                )
            ],
            subtasks: [],
            focusEntries: [
                BackupFocusEntry(
                    id: UUID(),
                    taskID: taskID,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            tags: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        let service = BackupService(context: container.mainContext)

        let validated = try service.validateImport(data)
        try service.applyImport(validated)

        let imported = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<FocusEntry>()).first)
        XCTAssertEqual(imported.task?.id, taskID)
        XCTAssertEqual(imported.stateRawValue, "")
        XCTAssertEqual(imported.note, "")
    }

    func testExportOmitsLegacyTaskFocusMetadata() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let task = TaskItem(title: "等待评审")
        let entry = FocusEntry(state: .focused)
        entry.stateRawValue = "paused"
        entry.note = "旧任务备注"
        entry.task = task
        task.focusEntry = entry
        container.mainContext.insert(task)
        container.mainContext.insert(entry)
        try container.mainContext.save()

        let exported = try BackupService(context: container.mainContext).exportSnapshot(now: .now)
        let json = try XCTUnwrap(String(data: exported, encoding: .utf8))

        XCTAssertFalse(json.contains("\"stateRawValue\""))
        XCTAssertFalse(json.contains("旧任务备注"))
    }

    func testRejectsUnsupportedSchemaAndWritesNothing() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let service = BackupService(context: container.mainContext)
        let bad = """
        {"schemaVersion":99,"exportedAt":"1970-01-01T00:00:00Z","projects":[],"columns":[],"tasks":[],"subtasks":[],"tags":[]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try service.validateImport(bad))
        let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        XCTAssertTrue(tasks.isEmpty)
    }

    func testRejectsOutOfRangeCoordinates() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let service = BackupService(context: container.mainContext)
        let envelope = BackupEnvelope(
            exportedAt: .now,
            projects: [],
            columns: [],
            tasks: [
                BackupTask(
                    id: UUID(),
                    title: "Bad",
                    details: "",
                    urgency: 5,
                    importance: 0,
                    dueAt: nil,
                    reminderAt: nil,
                    estimatedMinutes: nil,
                    isCompleted: false,
                    completedAt: nil,
                    previousBoardColumnID: nil,
                    manualOrder: 0,
                    createdAt: .now,
                    updatedAt: .now,
                    projectID: nil,
                    boardColumnID: nil,
                    tagIDs: []
                )
            ],
            subtasks: [],
            tags: []
        )
        let data = try JSONEncoder().encode(envelope)
        XCTAssertThrowsError(try service.validateImport(data))
    }
}
