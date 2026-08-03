public enum TaskFocusState: String, Codable, CaseIterable, Sendable {
    case focused
    case paused
    case blocked
    case waiting
}
