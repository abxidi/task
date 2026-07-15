import SwiftUI
import TaskDomain
import TaskPersistence

@MainActor
final class TaskEditorModel: ObservableObject {
    @Published var draft: TaskDraft
    @Published var errorMessage: String?
    @Published var showDiscardConfirmation = false

    let original: TaskDraft
    let existing: TaskItem?

    init(draft: TaskDraft, existing: TaskItem? = nil) {
        self.draft = draft
        self.original = draft
        self.existing = existing
    }

    var canSave: Bool {
        guard let validated = try? draft.validated() else { return false }
        return !validated.title.isEmpty
    }

    var isDirty: Bool {
        draft != original
    }

    static func draft(from item: TaskItem) -> TaskDraft {
        TaskDraft(
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
    }
}

enum TaskEditorMode {
    case create
    case createInColumn(UUID)
    case edit(TaskItem)
}
