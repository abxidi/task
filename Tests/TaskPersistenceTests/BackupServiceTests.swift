import Foundation
import SwiftData
import XCTest
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
