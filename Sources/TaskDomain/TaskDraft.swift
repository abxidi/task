import Foundation

public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var details: String
    public var coordinate: PriorityCoordinate
    public var dueAt: Date?
    public var reminderAt: Date?
    public var estimatedMinutes: Int?
    public var isCompleted: Bool
    public var subtasks: [String]
    public var subtaskCompletion: [Bool]
    public var projectID: UUID?
    public var boardColumnID: UUID?
    public var tagNames: [String]

    public init(
        title: String,
        details: String = "",
        coordinate: PriorityCoordinate = .init(uncheckedUrgency: 0, importance: 0),
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        isCompleted: Bool = false,
        subtasks: [String] = [],
        subtaskCompletion: [Bool] = [],
        projectID: UUID? = nil,
        boardColumnID: UUID? = nil,
        tagNames: [String] = []
    ) {
        self.title = title
        self.details = details
        self.coordinate = coordinate
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.subtasks = subtasks
        self.subtaskCompletion = subtaskCompletion
        self.projectID = projectID
        self.boardColumnID = boardColumnID
        self.tagNames = tagNames
    }

    public func validated() throws -> Self {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw TaskDraftError.emptyTitle }
        let normalizedSubtasks = subtasks.enumerated().compactMap { index, title -> (String, Bool)? in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return (trimmed, index < subtaskCompletion.count ? subtaskCompletion[index] : false)
        }
        copy.subtasks = normalizedSubtasks.map(\.0)
        copy.subtaskCompletion = normalizedSubtasks.map(\.1)
        copy.tagNames = tagNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let minutes = estimatedMinutes, minutes <= 0 { throw TaskDraftError.invalidEstimate }
        return copy
    }
}

public enum TaskDraftError: Error, Equatable {
    case emptyTitle
    case invalidEstimate
}
