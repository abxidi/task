import Foundation

public struct TaskReminder: Equatable, Sendable {
    public let taskID: UUID
    public let title: String
    public let fireAt: Date

    public init(taskID: UUID, title: String, fireAt: Date) {
        self.taskID = taskID
        self.title = title
        self.fireAt = fireAt
    }
}

public protocol ReminderScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(_ reminder: TaskReminder) async throws
    func cancel(taskID: UUID) async
}

public protocol NotificationCenterClient: Sendable {
    func requestAuthorization(options: UInt) async throws -> Bool
    func add(identifier: String, title: String, body: String, fireAt: Date) async throws
    func removePending(identifiers: [String]) async
}

public enum ReminderIdentifier {
    public static func make(taskID: UUID) -> String {
        "task.\(taskID.uuidString)"
    }
}
