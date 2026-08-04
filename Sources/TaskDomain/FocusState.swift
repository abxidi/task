public enum TaskFocusState: String, Codable, CaseIterable, Sendable {
    case focused
    case waiting
    case blocked

    public static let legacyPausedRawValue = "paused"

    public init?(rawValue: String) {
        switch rawValue {
        case Self.focused.rawValue:
            self = .focused
        case Self.waiting.rawValue, Self.legacyPausedRawValue:
            self = .waiting
        case Self.blocked.rawValue:
            self = .blocked
        default:
            return nil
        }
    }
}
