import Foundation
import SwiftData
import XCTest
import TaskAI
@testable import TaskPersistence

@MainActor
final class PlanProposalApplierTests: XCTestCase {
    func testUnacceptedChangesDoNothing() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "A")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let change = ProposedTaskChange(taskID: item.id, dueAt: Date(timeIntervalSince1970: 10), estimatedMinutes: 20, addedSubtasks: ["x"], reason: "r")
        let applier = PlanProposalApplier(context: container.mainContext)
        try applier.apply([ReviewedTaskChange(proposal: change, isAccepted: false)], tasksByID: [item.id: item])
        XCTAssertNil(item.dueAt)
        XCTAssertNil(item.estimatedMinutes)
        XCTAssertTrue(item.subtasks.isEmpty)
    }

    func testAcceptedChangesUpdateAllowedFieldsOnly() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let item = TaskItem(title: "A")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let due = Date(timeIntervalSince1970: 42)
        let change = ProposedTaskChange(taskID: item.id, dueAt: due, estimatedMinutes: 25, addedSubtasks: ["One"], reason: "r")
        let applier = PlanProposalApplier(context: container.mainContext)
        try applier.apply([ReviewedTaskChange(proposal: change, isAccepted: true)], tasksByID: [item.id: item])
        XCTAssertEqual(item.dueAt, due)
        XCTAssertEqual(item.estimatedMinutes, 25)
        XCTAssertEqual(item.subtasks.map(\.title), ["One"])
    }

    func testMissingTaskAborts() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let applier = PlanProposalApplier(context: container.mainContext)
        let missing = UUID()
        XCTAssertThrowsError(
            try applier.apply(
                [ReviewedTaskChange(proposal: ProposedTaskChange(taskID: missing, reason: "r"), isAccepted: true)],
                tasksByID: [:]
            )
        )
    }
}
