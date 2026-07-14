import Foundation
import SwiftData

@Model
public final class BoardColumn {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var order: Int
    public var isCompletionColumn: Bool
    public var project: Project?
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.boardColumn) public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, order: Int, isCompletionColumn: Bool = false) {
        self.id = id
        self.name = name
        self.order = order
        self.isCompletionColumn = isCompletionColumn
        self.tasks = []
    }
}
