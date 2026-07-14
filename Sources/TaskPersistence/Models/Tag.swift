import Foundation
import SwiftData

@Model
public final class Tag {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String?
    public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.tasks = []
    }
}
