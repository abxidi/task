import Foundation

public struct PlanningTask: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let details: String
    public let subtasks: [String]
    public let urgency: Int
    public let importance: Int
    public let dueAt: Date?
    public let estimatedMinutes: Int?

    public init(
        id: UUID,
        title: String,
        details: String,
        subtasks: [String],
        urgency: Int,
        importance: Int,
        dueAt: Date?,
        estimatedMinutes: Int?
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.subtasks = subtasks
        self.urgency = urgency
        self.importance = importance
        self.dueAt = dueAt
        self.estimatedMinutes = estimatedMinutes
    }
}

public struct PlanningRequest: Codable, Equatable, Sendable {
    public let tasks: [PlanningTask]
    public let capacityMinutes: Int
    public let rangeStart: Date
    public let rangeEnd: Date

    public init(tasks: [PlanningTask], capacityMinutes: Int, rangeStart: Date, rangeEnd: Date) {
        self.tasks = tasks
        self.capacityMinutes = capacityMinutes
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}

public protocol AIPlanningClient: Sendable {
    func proposePlan(_ request: PlanningRequest) async throws -> PlanProposal
}
