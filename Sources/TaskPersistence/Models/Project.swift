import Foundation
import SwiftData

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    public var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \BoardColumn.project) public var boardColumns: [BoardColumn]
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project) public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, colorHex: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = createdAt
        self.boardColumns = []
        self.tasks = []
    }
}
