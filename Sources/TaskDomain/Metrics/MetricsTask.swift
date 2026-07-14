import Foundation

public struct MetricsTask<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let coordinate: PriorityCoordinate
    public let dueAt: Date?
    public let estimatedMinutes: Int?
    public let isCompleted: Bool
    public let completedAt: Date?

    public init(id: ID, coordinate: PriorityCoordinate, dueAt: Date?, estimatedMinutes: Int?, isCompleted: Bool, completedAt: Date?) {
        self.id = id
        self.coordinate = coordinate
        self.dueAt = dueAt
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
