import Foundation
import SwiftData
import TaskDomain

func removeFocusEntry(for task: TaskItem, from context: ModelContext) {
    guard let entry = task.focusEntry else { return }
    task.focusEntry = nil
    context.delete(entry)
}

func clearFocusData(for subtask: Subtask) {
    subtask.focusState = nil
    subtask.focusNote = nil
    subtask.focusUpdatedAt = nil
}

@MainActor
public final class FocusRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func upsert(task: TaskItem, state: TaskFocusState, note: String) throws -> FocusEntry {
        let entry: FocusEntry
        if let current = task.focusEntry {
            entry = current
            entry.stateRawValue = ""
            entry.note = ""
            entry.updatedAt = .now
        } else {
            entry = FocusEntry(state: .focused, note: "")
            entry.stateRawValue = ""
            entry.task = task
            task.focusEntry = entry
            context.insert(entry)
        }
        try context.save()
        return entry
    }

    public func start(_ subtask: Subtask) throws {
        clearLegacyTaskLevelMetadata(for: subtask.task)
        subtask.focusState = .focused
        subtask.focusNote = ""
        subtask.focusUpdatedAt = .now
        try context.save()
    }

    public func update(_ subtask: Subtask, state: TaskFocusState, note: String) throws {
        clearLegacyTaskLevelMetadata(for: subtask.task)
        subtask.focusState = state
        subtask.focusNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        subtask.focusUpdatedAt = .now
        try context.save()
    }

    public func fetchEntries() throws -> [FocusEntry] {
        try context.fetch(FetchDescriptor<FocusEntry>(sortBy: [SortDescriptor(\FocusEntry.updatedAt, order: .reverse)]))
    }

    @discardableResult
    public func migrateLegacyStates() throws -> Int {
        let entries = try context.fetch(FetchDescriptor<FocusEntry>())
        let entriesWithLegacyMetadata = entries.filter {
            !$0.stateRawValue.isEmpty || !$0.note.isEmpty
        }
        guard !entriesWithLegacyMetadata.isEmpty else { return 0 }

        for entry in entriesWithLegacyMetadata {
            entry.stateRawValue = ""
            entry.note = ""
        }
        try context.save()
        return entriesWithLegacyMetadata.count
    }

    public func remove(_ entry: FocusEntry) throws {
        context.delete(entry)
        try context.save()
    }

    private func clearLegacyTaskLevelMetadata(for task: TaskItem?) {
        guard let entry = task?.focusEntry else { return }
        entry.stateRawValue = ""
        entry.note = ""
        entry.updatedAt = .now
    }
}
