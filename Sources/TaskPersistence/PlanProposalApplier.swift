import Foundation
import SwiftData
import TaskAI

@MainActor
public final class PlanProposalApplier {
    private let context: ModelContext
    private let save: () throws -> Void

    public init(context: ModelContext, save: (() throws -> Void)? = nil) {
        self.context = context
        self.save = save ?? { try context.save() }
    }

    public func apply(_ reviewed: [ReviewedTaskChange], tasksByID: [UUID: TaskItem]) throws {
        let accepted = reviewed.filter(\.isAccepted).map(\.proposal)
        do {
            for change in accepted {
                guard let task = tasksByID[change.taskID] else { throw PlanApplyError.missingTask(change.taskID) }
                if let dueAt = change.dueAt {
                    task.dueAt = dueAt
                }
                if let minutes = change.estimatedMinutes {
                    task.estimatedMinutes = minutes
                }
                let start = task.subtasks.count
                let appended = change.addedSubtasks.enumerated().map { offset, title in
                    Subtask(title: title, order: start + offset)
                }
                for subtask in appended {
                    context.insert(subtask)
                    subtask.task = task
                }
                task.subtasks.append(contentsOf: appended)
                task.updatedAt = .now
            }
            try save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

public enum PlanApplyError: Error, Equatable {
    case missingTask(UUID)
}
