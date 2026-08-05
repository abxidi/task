import Foundation

public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var details: String
    public var startAt: Date?
    public var coordinate: PriorityCoordinate
    public var dueAt: Date?
    public var reminderAt: Date?
    public var estimatedMinutes: Int?
    public var isCompleted: Bool
    public var subtasks: [String]
    public var subtaskCompletion: [Bool]
    public var subtaskIDs: [UUID]
    public var projectID: UUID?
    public var boardColumnID: UUID?
    public var tagNames: [String]

    public init(
        title: String,
        details: String = "",
        startAt: Date? = nil,
        coordinate: PriorityCoordinate = .init(uncheckedUrgency: 0, importance: 0),
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        isCompleted: Bool = false,
        subtasks: [String] = [],
        subtaskCompletion: [Bool] = [],
        subtaskIDs: [UUID] = [],
        projectID: UUID? = nil,
        boardColumnID: UUID? = nil,
        tagNames: [String] = []
    ) {
        self.title = title
        self.details = details
        self.startAt = startAt
        self.coordinate = coordinate
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.subtasks = subtasks
        self.subtaskCompletion = subtaskCompletion
        self.subtaskIDs = Self.alignedSubtaskIDs(subtaskIDs, count: subtasks.count)
        self.projectID = projectID
        self.boardColumnID = boardColumnID
        self.tagNames = tagNames
    }

    public func validated() throws -> Self {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw TaskDraftError.emptyTitle }
        let normalizedSubtasks = subtasks.enumerated().compactMap { index, title -> (UUID, String, Bool)? in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let id = index < subtaskIDs.count ? subtaskIDs[index] : UUID()
            return (id, trimmed, index < subtaskCompletion.count ? subtaskCompletion[index] : false)
        }
        copy.subtaskIDs = normalizedSubtasks.map(\.0)
        copy.subtasks = normalizedSubtasks.map(\.1)
        copy.subtaskCompletion = normalizedSubtasks.map(\.2)
        copy.normalizeSubtaskOrdering()
        copy.tagNames = tagNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let minutes = estimatedMinutes, minutes <= 0 { throw TaskDraftError.invalidEstimate }
        if let startAt = startAt, let dueAt = dueAt, startAt > dueAt {
            throw TaskDraftError.invalidTimeRange
        }
        return copy
    }

    public mutating func toggleSubtaskCompletion(at index: Int) {
        normalizeSubtaskOrdering()
        guard subtasks.indices.contains(index) else { return }
        subtaskCompletion[index].toggle()
    }

    public mutating func addSubtask(_ title: String) {
        normalizeSubtaskOrdering()
        subtasks.append(title)
        subtaskCompletion.append(false)
        subtaskIDs.append(UUID())
    }

    public mutating func normalizeSubtaskOrdering() {
        subtaskIDs = Self.alignedSubtaskIDs(subtaskIDs, count: subtasks.count)
        subtaskCompletion = Array(subtaskCompletion.prefix(subtasks.count))
        if subtaskCompletion.count < subtasks.count {
            subtaskCompletion.append(
                contentsOf: Array(repeating: false, count: subtasks.count - subtaskCompletion.count)
            )
        }
    }

    private static func alignedSubtaskIDs(_ ids: [UUID], count: Int) -> [UUID] {
        if ids.count >= count { return Array(ids.prefix(count)) }
        return ids + Array(repeating: (), count: count - ids.count).map { _ in UUID() }
    }
}

public enum SubtaskOrder {
    public static func incompleteFirst<Element>(
        _ items: [Element],
        isCompleted: (Element) -> Bool
    ) -> [Element] {
        items.enumerated()
            .sorted { left, right in
                let leftCompleted = isCompleted(left.element)
                let rightCompleted = isCompleted(right.element)
                if leftCompleted == rightCompleted {
                    return left.offset < right.offset
                }
                return !leftCompleted
            }
            .map(\.element)
    }
}

public enum TaskDraftError: Error, Equatable {
    case emptyTitle
    case invalidEstimate
    case invalidTimeRange
}
