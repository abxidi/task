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
        copy.normalizeSubtaskOrdering()
        copy.tagNames = tagNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let minutes = estimatedMinutes, minutes <= 0 { throw TaskDraftError.invalidEstimate }
        return copy
    }

    public mutating func toggleSubtaskCompletion(at index: Int) {
        normalizeSubtaskOrdering()
        guard subtasks.indices.contains(index) else { return }

        let title = subtasks.remove(at: index)
        let wasCompleted = index < subtaskCompletion.count ? subtaskCompletion.remove(at: index) : false

        if wasCompleted {
            subtasks.insert(title, at: 0)
            subtaskCompletion.insert(false, at: 0)
        } else {
            subtasks.append(title)
            subtaskCompletion.append(true)
        }
    }

    public mutating func addSubtask(_ title: String) {
        normalizeSubtaskOrdering()
        let insertionIndex = subtaskCompletion.firstIndex(of: true) ?? subtasks.endIndex
        subtasks.insert(title, at: insertionIndex)
        subtaskCompletion.insert(false, at: insertionIndex)
    }

    public mutating func normalizeSubtaskOrdering() {
        let entries = subtasks.enumerated().map { index, title in
            (title: title, isCompleted: index < subtaskCompletion.count ? subtaskCompletion[index] : false)
        }
        let ordered = SubtaskOrder.incompleteFirst(entries) { $0.isCompleted }
        subtasks = ordered.map(\.title)
        subtaskCompletion = ordered.map(\.isCompleted)
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
}
