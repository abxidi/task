import SwiftData
import XCTest
import TaskPersistence
@testable import TaskApp

@MainActor
final class MarkdownDraftSessionTests: XCTestCase {
    func testCancelRestoresTheOpeningDetails() {
        let session = MarkdownDraftSession(details: "before")
        session.details = "after"

        session.cancel()

        XCTAssertEqual(session.details, "before")
        XCTAssertFalse(session.isDirty)
    }

    func testSaveUpdatesDetailsWithoutChangingTaskMetadata() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "Keep title")
        item.details = "before"
        item.importance = 2
        container.mainContext.insert(item)
        try container.mainContext.save()
        let repository = TaskRepository(context: container.mainContext)
        let session = MarkdownDraftSession(details: item.details)
        session.details = "# after"

        try session.save(using: repository, for: item)

        XCTAssertEqual(item.details, "# after")
        XCTAssertEqual(item.title, "Keep title")
        XCTAssertEqual(item.importance, 2)
        XCTAssertFalse(session.isDirty)
    }
}
