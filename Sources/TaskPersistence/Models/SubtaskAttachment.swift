import Foundation
import SwiftData

@Model
public final class SubtaskAttachment {
    @Attribute(.unique) public var id: UUID
    public var imageData: Data
    public var thumbnailData: Data
    public var createdAt: Date
    public var subtask: Subtask?

    public init(
        id: UUID = UUID(),
        imageData: Data,
        thumbnailData: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }
}
