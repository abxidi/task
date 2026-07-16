import SwiftUI
import TaskDomain
import TaskPersistence

@MainActor
final class TaskEditorModel: ObservableObject {
    @Published var draft: TaskDraft
    @Published var errorMessage: String?

    private(set) var existing: TaskItem?

    init(draft: TaskDraft, existing: TaskItem? = nil) {
        self.draft = draft
        self.existing = existing
    }

    @discardableResult
    func autoSave(using repository: TaskRepository) throws -> TaskItem? {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return existing
        }

        if let existing {
            var metadataDraft = draft
            metadataDraft.details = existing.details
            try repository.updateTask(existing, with: metadataDraft)
            return existing
        }

        let created = try repository.saveNewTask(draft)
        existing = created
        return created
    }

    func acceptSavedDetails(_ details: String) {
        draft.details = details
    }

    static func draft(from item: TaskItem) -> TaskDraft {
        var draft = TaskDraft(
            title: item.title,
            details: item.details,
            coordinate: .init(uncheckedUrgency: item.urgency, importance: item.importance),
            dueAt: item.dueAt,
            reminderAt: item.reminderAt,
            estimatedMinutes: item.estimatedMinutes,
            isCompleted: item.isCompleted,
            subtasks: item.subtasks.sorted { $0.order < $1.order }.map(\.title),
            subtaskCompletion: item.subtasks.sorted { $0.order < $1.order }.map(\.isCompleted),
            projectID: item.project?.id,
            boardColumnID: item.boardColumn?.id,
            tagNames: item.tags.map(\.name)
        )
        draft.normalizeSubtaskOrdering()
        return draft
    }
}

enum TaskEditorMode {
    case create
    case createInColumn(UUID)
    case edit(TaskItem)
}
