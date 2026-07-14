public enum PriorityQuadrant: String, Codable, CaseIterable, Sendable {
    case actNow
    case plan
    case delegate
    case `defer`
    case undecided
}
