import Foundation

public enum PlanProposalIssue: Equatable, Sendable {
    case tooManyChanges(Int)
    case unknownTask(UUID)
    case invalidEstimate(taskID: UUID, minutes: Int)
    case dateOutsideRange(taskID: UUID)
    case tooManySubtasks(taskID: UUID, count: Int)
    case invalidSubtaskTitle(taskID: UUID, index: Int)
}

public struct PlanProposalValidationError: Error, Equatable, Sendable {
    public let issues: [PlanProposalIssue]

    public init(issues: [PlanProposalIssue]) {
        self.issues = issues
    }
}

public enum PlanProposalValidator {
    public static func validate(
        _ proposal: PlanProposal,
        allowedTaskIDs: Set<UUID>,
        range: ClosedRange<Date>
    ) throws -> PlanProposal {
        var issues: [PlanProposalIssue] = []
        if proposal.changes.count > 100 { issues.append(.tooManyChanges(proposal.changes.count)) }

        for change in proposal.changes {
            if !allowedTaskIDs.contains(change.taskID) { issues.append(.unknownTask(change.taskID)) }
            if let minutes = change.estimatedMinutes, !(1...1_440).contains(minutes) {
                issues.append(.invalidEstimate(taskID: change.taskID, minutes: minutes))
            }
            if let date = change.dueAt, !range.contains(date) {
                issues.append(.dateOutsideRange(taskID: change.taskID))
            }
            if change.addedSubtasks.count > 20 {
                issues.append(.tooManySubtasks(taskID: change.taskID, count: change.addedSubtasks.count))
            }
            for (index, title) in change.addedSubtasks.enumerated() {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.count > 300 {
                    issues.append(.invalidSubtaskTitle(taskID: change.taskID, index: index))
                }
            }
        }

        guard issues.isEmpty else { throw PlanProposalValidationError(issues: issues) }
        return proposal
    }
}
