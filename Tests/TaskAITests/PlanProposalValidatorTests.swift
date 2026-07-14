import Foundation
import XCTest
@testable import TaskAI

final class PlanProposalValidatorTests: XCTestCase {
    func testRejectsUnknownTaskAndInvalidFields() {
        let taskID = UUID()
        let range = Date(timeIntervalSince1970: 100)...Date(timeIntervalSince1970: 200)
        let proposal = PlanProposal(
            summary: "x",
            changes: [
                ProposedTaskChange(taskID: UUID(), estimatedMinutes: 0, addedSubtasks: [""], reason: "bad"),
                ProposedTaskChange(taskID: taskID, dueAt: Date(timeIntervalSince1970: 999), estimatedMinutes: 30, addedSubtasks: ["ok"], reason: "range")
            ]
        )
        XCTAssertThrowsError(try PlanProposalValidator.validate(proposal, allowedTaskIDs: [taskID], range: range)) { error in
            let issues = (error as? PlanProposalValidationError)?.issues ?? []
            XCTAssertTrue(issues.contains(where: {
                if case .unknownTask = $0 { return true }
                return false
            }))
            XCTAssertTrue(issues.contains(where: {
                if case .invalidEstimate = $0 { return true }
                return false
            }))
            XCTAssertTrue(issues.contains(where: {
                if case .dateOutsideRange = $0 { return true }
                return false
            }))
        }
    }

    func testAcceptsValidProposalAndEncodesAllowListOnly() throws {
        let taskID = UUID()
        let range = Date(timeIntervalSince1970: 100)...Date(timeIntervalSince1970: 200)
        let proposal = PlanProposal(
            summary: "ok",
            changes: [
                ProposedTaskChange(taskID: taskID, dueAt: Date(timeIntervalSince1970: 150), estimatedMinutes: 45, addedSubtasks: ["Split"], reason: "focus")
            ]
        )
        let validated = try PlanProposalValidator.validate(proposal, allowedTaskIDs: [taskID], range: range)
        let data = try JSONEncoder().encode(validated)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("dueAt"))
        XCTAssertTrue(json.contains("estimatedMinutes"))
        XCTAssertTrue(json.contains("addedSubtasks"))
        XCTAssertFalse(json.contains("delete"))
        XCTAssertFalse(json.contains("archive"))
    }
}
