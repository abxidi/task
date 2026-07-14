import Foundation

public struct BackupEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let projects: [BackupProject]
    public let columns: [BackupColumn]
    public let tasks: [BackupTask]
    public let subtasks: [BackupSubtask]
    public let tags: [BackupTag]

    public init(
        schemaVersion: Int = BackupEnvelope.currentSchemaVersion,
        exportedAt: Date,
        projects: [BackupProject],
        columns: [BackupColumn],
        tasks: [BackupTask],
        subtasks: [BackupSubtask],
        tags: [BackupTag]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.projects = projects
        self.columns = columns
        self.tasks = tasks
        self.subtasks = subtasks
        self.tags = tags
    }
}

public struct BackupProject: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let colorHex: String
    public let isArchived: Bool
    public let createdAt: Date
}

public struct BackupColumn: Codable, Equatable, Sendable {
    public let id: UUID
    public let projectID: UUID
    public let name: String
    public let order: Int
    public let isCompletionColumn: Bool
}

public struct BackupTask: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let details: String
    public let urgency: Int
    public let importance: Int
    public let dueAt: Date?
    public let reminderAt: Date?
    public let estimatedMinutes: Int?
    public let isCompleted: Bool
    public let completedAt: Date?
    public let previousBoardColumnID: UUID?
    public let manualOrder: Double
    public let createdAt: Date
    public let updatedAt: Date
    public let projectID: UUID?
    public let boardColumnID: UUID?
    public let tagIDs: [UUID]
}

public struct BackupSubtask: Codable, Equatable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let title: String
    public let isCompleted: Bool
    public let order: Int
    public let createdAt: Date
}

public struct BackupTag: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let colorHex: String?
}
