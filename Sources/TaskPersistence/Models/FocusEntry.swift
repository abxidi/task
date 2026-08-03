import Foundation
import SwiftData
import TaskDomain

@Model
public final class FocusEntry {
    @Attribute(.unique) public var id: UUID
    public var stateRawValue: String
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date
    public var task: TaskItem?

    public var state: TaskFocusState {
        get { TaskFocusState(rawValue: stateRawValue) ?? .focused }
        set { stateRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        state: TaskFocusState,
        note: String = "",
        now: Date = .now
    ) {
        self.id = id
        self.stateRawValue = state.rawValue
        self.note = note
        self.createdAt = now
        self.updatedAt = now
    }
}
