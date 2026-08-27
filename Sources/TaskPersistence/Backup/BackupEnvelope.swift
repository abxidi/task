import Foundation

public struct BackupEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public let schemaVersion: Int
    public let exportedAt: Date
    public let projects: [BackupProject]
    public let columns: [BackupColumn]
    public let tasks: [BackupTask]
    public let subtasks: [BackupSubtask]
    public let attachments: [BackupSubtaskAttachment]
    public let focusEntries: [BackupFocusEntry]
    public let tags: [BackupTag]

    public init(
        schemaVersion: Int = BackupEnvelope.currentSchemaVersion,
        exportedAt: Date,
        projects: [BackupProject],
        columns: [BackupColumn],
        tasks: [BackupTask],
        subtasks: [BackupSubtask],
        attachments: [BackupSubtaskAttachment] = [],
        focusEntries: [BackupFocusEntry] = [],
        tags: [BackupTag]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.projects = projects
        self.columns = columns
        self.tasks = tasks
        self.subtasks = subtasks
        self.attachments = attachments
        self.focusEntries = focusEntries
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, projects, columns, tasks, subtasks, attachments, focusEntries, tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        projects = try container.decode([BackupProject].self, forKey: .projects)
        columns = try container.decode([BackupColumn].self, forKey: .columns)
        tasks = try container.decode([BackupTask].self, forKey: .tasks)
        subtasks = try container.decode([BackupSubtask].self, forKey: .subtasks)
        attachments = try container.decodeIfPresent([BackupSubtaskAttachment].self, forKey: .attachments) ?? []
        focusEntries = try container.decodeIfPresent([BackupFocusEntry].self, forKey: .focusEntries) ?? []
        tags = try container.decode([BackupTag].self, forKey: .tags)
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
    public let startAt: Date?
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

    public init(
        id: UUID,
        title: String,
        details: String,
        startAt: Date? = nil,
        urgency: Int,
        importance: Int,
        dueAt: Date?,
        reminderAt: Date?,
        estimatedMinutes: Int?,
        isCompleted: Bool,
        completedAt: Date?,
        previousBoardColumnID: UUID?,
        manualOrder: Double,
        createdAt: Date,
        updatedAt: Date,
        projectID: UUID?,
        boardColumnID: UUID?,
        tagIDs: [UUID]
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.startAt = startAt
        self.urgency = urgency
        self.importance = importance
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.previousBoardColumnID = previousBoardColumnID
        self.manualOrder = manualOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectID = projectID
        self.boardColumnID = boardColumnID
        self.tagIDs = tagIDs
    }
}

public struct BackupSubtask: Codable, Equatable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let title: String
    public let isCompleted: Bool
    public let order: Int
    public let createdAt: Date
    public let focusStateRawValue: String?
    public let focusNote: String?
    public let focusUpdatedAt: Date?

    public init(
        id: UUID,
        taskID: UUID,
        title: String,
        isCompleted: Bool,
        order: Int,
        createdAt: Date,
        focusStateRawValue: String? = nil,
        focusNote: String? = nil,
        focusUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.isCompleted = isCompleted
        self.order = order
        self.createdAt = createdAt
        self.focusStateRawValue = focusStateRawValue
        self.focusNote = focusNote
        self.focusUpdatedAt = focusUpdatedAt
    }
}

public struct BackupSubtaskAttachment: Codable, Equatable, Sendable {
    public let id: UUID
    public let subtaskID: UUID
    public let imageData: Data
    public let thumbnailData: Data
    public let createdAt: Date
}

public struct BackupFocusEntry: Codable, Equatable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID, taskID: UUID, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.taskID = taskID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BackupTag: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let colorHex: String?
}
