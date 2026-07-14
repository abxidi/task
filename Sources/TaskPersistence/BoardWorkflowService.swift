import Foundation
import SwiftData

@MainActor
public final class BoardWorkflowService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func move(_ task: TaskItem, to column: BoardColumn, now: Date = .now) throws {
        guard task.project?.id == column.project?.id else {
            throw BoardWorkflowError.projectMismatch
        }
        if column.isCompletionColumn {
            if let current = task.boardColumn, !current.isCompletionColumn {
                task.previousBoardColumnID = current.id
            }
            task.isCompleted = true
            task.completedAt = now
        } else {
            task.isCompleted = false
            task.completedAt = nil
        }
        task.boardColumn = column
        task.updatedAt = now
        try context.save()
    }
}

public enum BoardWorkflowError: Error, Equatable {
    case projectMismatch
    case missingCompletionColumn
    case cannotArchiveCompletionColumn
}
