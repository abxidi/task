import SwiftData
import XCTest
import TaskDomain
import TaskPersistence
@testable import TaskApp

@MainActor
final class TaskEditorAutoSaveTests: XCTestCase {
    func testEmptyNewDraftDoesNotCreateTask() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(draft: TaskDraft(title: "   "))

        XCTAssertNil(try model.autoSave(using: repository))
        XCTAssertTrue(try repository.fetchAllTasks().isEmpty)
    }

    func testFirstValidTitleCreatesExactlyOneTask() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(draft: TaskDraft(title: "Draft launch plan"))

        let item = try XCTUnwrap(model.autoSave(using: repository))

        XCTAssertEqual(try repository.fetchAllTasks().count, 1)
        XCTAssertEqual(item.title, "Draft launch plan")
    }

    func testExistingTaskAutosavesEditedInlineNote() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "任务")
        item.details = "旧备注"
        container.mainContext.insert(item)
        try container.mainContext.save()
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(
            draft: TaskDraft(title: "任务", details: "新备注"),
            existing: item
        )

        _ = try model.autoSave(using: repository)

        XCTAssertEqual(item.details, "新备注")
    }

    func testMetadataAutosaveDoesNotOverwriteMarkdownDetails() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "Draft launch plan")
        item.details = "# Markdown body"
        container.mainContext.insert(item)
        try container.mainContext.save()
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(
            draft: TaskDraft(title: "Draft launch plan", details: "Stale details"),
            existing: item
        )
        model.acceptSavedDetails("# Markdown body")
        model.draft.coordinate = .init(uncheckedUrgency: 3, importance: 2)

        let updated = try XCTUnwrap(model.autoSave(using: repository))

        XCTAssertTrue(item === updated)
        XCTAssertEqual(try repository.fetchAllTasks().count, 1)
        XCTAssertEqual(item.details, "# Markdown body")
        XCTAssertEqual(item.urgency, 3)
        XCTAssertEqual(item.importance, 2)
    }

    func testExistingTaskIsUpdatedInPlace() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "Old title")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(
            draft: TaskDraft(title: "New title", details: "Stale details"),
            existing: item
        )

        let updated = try XCTUnwrap(model.autoSave(using: repository))

        XCTAssertTrue(item === updated)
        XCTAssertEqual(item.title, "New title")
        XCTAssertEqual(item.details, "Stale details")
        XCTAssertEqual(try repository.fetchAllTasks().count, 1)
    }
}
