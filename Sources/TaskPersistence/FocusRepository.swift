import Foundation
import SwiftData
import TaskDomain

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
            entry.state = state
            entry.note = note
            entry.updatedAt = .now
        } else {
            entry = FocusEntry(state: state, note: note)
            entry.task = task
            task.focusEntry = entry
            context.insert(entry)
        }
        try context.save()
        return entry
    }

    public func fetchEntries() throws -> [FocusEntry] {
        try context.fetch(FetchDescriptor<FocusEntry>(sortBy: [SortDescriptor(\FocusEntry.updatedAt, order: .reverse)]))
    }

    @discardableResult
    public func migrateLegacyStates() throws -> Int {
        let entries = try context.fetch(FetchDescriptor<FocusEntry>())
        let legacyEntries = entries.filter { $0.stateRawValue == TaskFocusState.legacyPausedRawValue }
        guard !legacyEntries.isEmpty else { return 0 }

        for entry in legacyEntries {
            entry.state = .waiting
        }
        try context.save()
        return legacyEntries.count
    }

    public func remove(_ entry: FocusEntry) throws {
        context.delete(entry)
        try context.save()
    }
}
