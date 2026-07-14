import Foundation

public struct PlanProposal: Codable, Equatable, Sendable {
    public let summary: String
    public let changes: [ProposedTaskChange]

    public init(summary: String, changes: [ProposedTaskChange]) {
        self.summary = summary
        self.changes = changes
    }
}

public struct ProposedTaskChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let dueAt: Date?
    public let estimatedMinutes: Int?
    public let addedSubtasks: [String]
    public let reason: String

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        dueAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        addedSubtasks: [String] = [],
        reason: String
    ) {
        self.id = id
        self.taskID = taskID
        self.dueAt = dueAt
        self.estimatedMinutes = estimatedMinutes
        self.addedSubtasks = addedSubtasks
        self.reason = reason
    }
}

public struct ReviewedTaskChange: Equatable, Sendable {
    public let proposal: ProposedTaskChange
    public let isAccepted: Bool

    public init(proposal: ProposedTaskChange, isAccepted: Bool) {
        self.proposal = proposal
        self.isAccepted = isAccepted
    }
}
