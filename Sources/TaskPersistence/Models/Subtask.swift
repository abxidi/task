import Foundation
import SwiftData
import TaskDomain

@Model
public final class Subtask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var order: Int
    public var createdAt: Date
    public var focusStateRawValue: String?
    public var focusNote: String?
    public var focusUpdatedAt: Date?
    public var task: TaskItem?
    @Relationship(deleteRule: .cascade, inverse: \SubtaskAttachment.subtask) public var attachments: [SubtaskAttachment]

    public init(id: UUID = UUID(), title: String, order: Int, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.isCompleted = false
        self.order = order
        self.createdAt = createdAt
        self.focusStateRawValue = nil
        self.focusNote = nil
        self.focusUpdatedAt = nil
        self.attachments = []
    }

    public var focusState: TaskFocusState? {
        get { focusStateRawValue.flatMap(TaskFocusState.init(rawValue:)) }
        set { focusStateRawValue = newValue?.rawValue }
    }
}
