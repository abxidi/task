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

    func testLaterDraftChangesUpdateTheCreatedTask() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(draft: TaskDraft(title: "Draft launch plan"))

        let created = try XCTUnwrap(model.autoSave(using: repository))
        model.draft.details = "Context"
        model.draft.coordinate = .init(uncheckedUrgency: 3, importance: 2)

        let updated = try XCTUnwrap(model.autoSave(using: repository))

        XCTAssertTrue(created === updated)
        XCTAssertEqual(try repository.fetchAllTasks().count, 1)
        XCTAssertEqual(created.details, "Context")
        XCTAssertEqual(created.urgency, 3)
        XCTAssertEqual(created.importance, 2)
    }

    func testExistingTaskIsUpdatedInPlace() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "Old title")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let repository = TaskRepository(context: container.mainContext)
        let model = TaskEditorModel(
            draft: TaskDraft(title: "New title", details: "Updated details"),
            existing: item
        )

        let updated = try XCTUnwrap(model.autoSave(using: repository))

        XCTAssertTrue(item === updated)
        XCTAssertEqual(item.title, "New title")
        XCTAssertEqual(item.details, "Updated details")
        XCTAssertEqual(try repository.fetchAllTasks().count, 1)
    }
}
