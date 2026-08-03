import Foundation
import SwiftData

@MainActor
public final class SubtaskAttachmentRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func add(imageData: Data, thumbnailData: Data, to subtask: Subtask) throws -> SubtaskAttachment {
        let attachment = SubtaskAttachment(imageData: imageData, thumbnailData: thumbnailData)
        attachment.subtask = subtask
        context.insert(attachment)
        try context.save()
        return attachment
    }

    public func remove(_ attachment: SubtaskAttachment) throws {
        context.delete(attachment)
        try context.save()
    }
}
