import Foundation
import SwiftData

@Model
public final class TaskItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var details: String
    public var startAt: Date?
    public var urgency: Int
    public var importance: Int
    public var dueAt: Date?
    public var reminderAt: Date?
    public var estimatedMinutes: Int?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var previousBoardColumnID: UUID?
    public var manualOrder: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var project: Project?
    public var boardColumn: BoardColumn?
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task) public var subtasks: [Subtask]
    @Relationship(inverse: \Tag.tasks) public var tags: [Tag]
    @Relationship(deleteRule: .cascade, inverse: \FocusEntry.task) public var focusEntry: FocusEntry?

    public init(id: UUID = UUID(), title: String, now: Date = .now) {
        self.id = id
        self.title = title
        self.details = ""
        self.startAt = nil
        self.urgency = 0
        self.importance = 0
        self.isCompleted = false
        self.manualOrder = now.timeIntervalSinceReferenceDate
        self.createdAt = now
        self.updatedAt = now
        self.subtasks = []
        self.tags = []
    }
}
