import Foundation
import SwiftData
import TaskDomain

@MainActor
public final class TaskRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createTask(title: String) throws -> TaskItem {
        try saveNewTask(TaskDraft(title: title))
    }

    @discardableResult
    public func saveNewTask(_ input: TaskDraft) throws -> TaskItem {
        let draft = try input.validated()
        let item = TaskItem(title: draft.title)
        apply(draft, to: item)
        context.insert(item)
        try context.save()
        return item
    }

    public func updateTask(_ item: TaskItem, with input: TaskDraft) throws {
        let draft = try input.validated()
        apply(draft, to: item)
        item.updatedAt = .now
        try context.save()
    }

    public func updatePriority(_ item: TaskItem, urgency: Int, importance: Int) throws {
        let coordinate = try PriorityCoordinate(urgency: urgency, importance: importance)
        item.urgency = coordinate.urgency
        item.importance = coordinate.importance
        item.updatedAt = .now
        try context.save()
    }

    public func setCompleted(_ item: TaskItem, isCompleted: Bool) throws {
        item.isCompleted = isCompleted
        item.completedAt = isCompleted ? .now : nil
        if isCompleted, let project = item.project {
            if let completion = project.boardColumns.first(where: \.isCompletionColumn) {
                if let current = item.boardColumn, !current.isCompletionColumn {
                    item.previousBoardColumnID = current.id
                }
                item.boardColumn = completion
            }
        } else if isCompleted,
                  let completion = try context.fetch(FetchDescriptor<BoardColumn>()).first(where: { $0.project == nil && $0.isCompletionColumn }) {
            if let current = item.boardColumn, !current.isCompletionColumn {
                item.previousBoardColumnID = current.id
            }
            item.boardColumn = completion
        } else if !isCompleted, let project = item.project {
            if let previousID = item.previousBoardColumnID,
               let previous = project.boardColumns.first(where: { $0.id == previousID }) {
                item.boardColumn = previous
            } else if let first = project.boardColumns.sorted(by: { $0.order < $1.order }).first(where: { !$0.isCompletionColumn }) {
                item.boardColumn = first
            } else {
                item.boardColumn = nil
            }
            item.previousBoardColumnID = nil
        } else if !isCompleted {
            let localLanes = try context.fetch(FetchDescriptor<BoardColumn>())
                .filter { $0.project == nil }
            if let previousID = item.previousBoardColumnID,
               let previous = localLanes.first(where: { $0.id == previousID }) {
                item.boardColumn = previous
            } else {
                item.boardColumn = localLanes
                    .filter { !$0.isCompletionColumn }
                    .min(by: { $0.order < $1.order })
            }
            item.previousBoardColumnID = nil
        }
        item.updatedAt = .now
        try context.save()
    }

    public func deleteTask(_ item: TaskItem) throws {
        context.delete(item)
        try context.save()
    }

    public func fetchAllTasks() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    }

    private func apply(_ draft: TaskDraft, to item: TaskItem) {
        item.title = draft.title
        item.details = draft.details
        item.urgency = draft.coordinate.urgency
        item.importance = draft.coordinate.importance
        item.dueAt = draft.dueAt
        item.reminderAt = draft.reminderAt
        item.estimatedMinutes = draft.estimatedMinutes
        item.isCompleted = draft.isCompleted
        item.completedAt = draft.isCompleted ? (item.completedAt ?? .now) : nil

        let existing = item.subtasks
        for subtask in existing {
            context.delete(subtask)
        }
        item.subtasks = draft.subtasks.enumerated().map { index, title in
            let subtask = Subtask(title: title, order: index)
            subtask.isCompleted = index < draft.subtaskCompletion.count ? draft.subtaskCompletion[index] : false
            return subtask
        }

        if let projectID = draft.projectID {
            item.project = try? context.fetch(FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectID })).first
        } else {
            item.project = nil
        }

        if let columnID = draft.boardColumnID {
            item.boardColumn = try? context.fetch(FetchDescriptor<BoardColumn>(predicate: #Predicate { $0.id == columnID })).first
        } else if item.project == nil {
            item.boardColumn = nil
        }

        let tags = draft.tagNames.map { name -> Tag in
            if let existing = try? context.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })).first {
                return existing
            }
            let tag = Tag(name: name)
            context.insert(tag)
            return tag
        }
        item.tags = tags
    }
}

public enum TaskRepositoryError: Error, Equatable {
    case emptyTitle
}
