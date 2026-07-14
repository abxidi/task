import Foundation
import SwiftData

@Model
public final class Subtask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var order: Int
    public var createdAt: Date
    public var task: TaskItem?

    public init(id: UUID = UUID(), title: String, order: Int, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.isCompleted = false
        self.order = order
        self.createdAt = createdAt
    }
}
