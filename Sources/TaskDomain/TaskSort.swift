import Foundation

public struct TaskSortValue<ID: Comparable>: Equatable {
    public let id: ID
    public let urgency: Int
    public let importance: Int
    public let dueAt: Date?
    public let createdAt: Date

    public init(id: ID, urgency: Int, importance: Int, dueAt: Date?, createdAt: Date) {
        self.id = id
        self.urgency = urgency
        self.importance = importance
        self.dueAt = dueAt
        self.createdAt = createdAt
    }
}

public enum TaskSort {
    public static func priority<ID>(_ lhs: TaskSortValue<ID>, _ rhs: TaskSortValue<ID>) -> Bool {
        if lhs.importance != rhs.importance { return lhs.importance > rhs.importance }
        if lhs.urgency != rhs.urgency { return lhs.urgency > rhs.urgency }
        if lhs.dueAt != rhs.dueAt { return (lhs.dueAt ?? .distantFuture) < (rhs.dueAt ?? .distantFuture) }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id < rhs.id
    }
}
