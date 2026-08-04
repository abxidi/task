import Foundation
import SwiftData
import TaskDomain

@MainActor
public protocol BackupServicing {
    func exportSnapshot(now: Date) throws -> Data
    func validateImport(_ data: Data) throws -> BackupEnvelope
    func applyImport(_ envelope: BackupEnvelope) throws
}

public enum BackupError: Error, Equatable {
    case unsupportedSchema(Int)
    case duplicateIDs
    case missingRelationship
    case invalidCoordinate
    case invalidTimeRange
    case multipleCompletionColumns
    case duplicateFocusEntry
    case invalidFocusState
}

@MainActor
public final class BackupService: BackupServicing {
    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(context: ModelContext) {
        self.context = context
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    public func exportSnapshot(now: Date) throws -> Data {
        let projects = try context.fetch(FetchDescriptor<Project>())
        let columns = try context.fetch(FetchDescriptor<BoardColumn>())
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        let subtasks = try context.fetch(FetchDescriptor<Subtask>())
        let attachments = try context.fetch(FetchDescriptor<SubtaskAttachment>())
        let focusEntries = try context.fetch(FetchDescriptor<FocusEntry>())
        let tags = try context.fetch(FetchDescriptor<Tag>())

        let envelope = BackupEnvelope(
            exportedAt: now,
            projects: projects.map {
                BackupProject(id: $0.id, name: $0.name, colorHex: $0.colorHex, isArchived: $0.isArchived, createdAt: $0.createdAt)
            },
            columns: columns.compactMap { column in
                guard let projectID = column.project?.id else { return nil }
                return BackupColumn(
                    id: column.id,
                    projectID: projectID,
                    name: column.name,
                    order: column.order,
                    isCompletionColumn: column.isCompletionColumn
                )
            },
            tasks: tasks.map {
                BackupTask(
                    id: $0.id,
                    title: $0.title,
                    details: $0.details,
                    startAt: $0.startAt,
                    urgency: $0.urgency,
                    importance: $0.importance,
                    dueAt: $0.dueAt,
                    reminderAt: $0.reminderAt,
                    estimatedMinutes: $0.estimatedMinutes,
                    isCompleted: $0.isCompleted,
                    completedAt: $0.completedAt,
                    previousBoardColumnID: $0.previousBoardColumnID,
                    manualOrder: $0.manualOrder,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    projectID: $0.project?.id,
                    boardColumnID: $0.boardColumn?.id,
                    tagIDs: $0.tags.map(\.id)
                )
            },
            subtasks: subtasks.compactMap { subtask in
                guard let taskID = subtask.task?.id else { return nil }
                return BackupSubtask(
                    id: subtask.id,
                    taskID: taskID,
                    title: subtask.title,
                    isCompleted: subtask.isCompleted,
                    order: subtask.order,
                    createdAt: subtask.createdAt
                )
            },
            attachments: attachments.compactMap { attachment in
                guard let subtaskID = attachment.subtask?.id else { return nil }
                return BackupSubtaskAttachment(
                    id: attachment.id,
                    subtaskID: subtaskID,
                    imageData: attachment.imageData,
                    thumbnailData: attachment.thumbnailData,
                    createdAt: attachment.createdAt
                )
            },
            focusEntries: focusEntries.compactMap { entry in
                guard let taskID = entry.task?.id else { return nil }
                return BackupFocusEntry(
                    id: entry.id,
                    taskID: taskID,
                    stateRawValue: entry.state.rawValue,
                    note: entry.note,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt
                )
            },
            tags: tags.map { BackupTag(id: $0.id, name: $0.name, colorHex: $0.colorHex) }
        )
        return try encoder.encode(envelope)
    }

    public func validateImport(_ data: Data) throws -> BackupEnvelope {
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard (1...BackupEnvelope.currentSchemaVersion).contains(envelope.schemaVersion) else {
            throw BackupError.unsupportedSchema(envelope.schemaVersion)
        }

        let projectIDs = envelope.projects.map(\.id)
        let columnIDs = envelope.columns.map(\.id)
        let taskIDs = envelope.tasks.map(\.id)
        let subtaskIDs = envelope.subtasks.map(\.id)
        let attachmentIDs = envelope.attachments.map(\.id)
        let focusIDs = envelope.focusEntries.map(\.id)
        let tagIDs = envelope.tags.map(\.id)
        let allIDs = projectIDs + columnIDs + taskIDs + subtaskIDs + attachmentIDs + focusIDs + tagIDs
        if Set(allIDs).count != allIDs.count {
            throw BackupError.duplicateIDs
        }

        let projectIDSet = Set(projectIDs)
        let columnIDSet = Set(columnIDs)
        let taskIDSet = Set(taskIDs)
        let tagIDSet = Set(tagIDs)

        for column in envelope.columns {
            guard projectIDSet.contains(column.projectID) else { throw BackupError.missingRelationship }
        }

        var completionByProject: [UUID: Int] = [:]
        for column in envelope.columns where column.isCompletionColumn {
            completionByProject[column.projectID, default: 0] += 1
        }
        if completionByProject.values.contains(where: { $0 > 1 }) {
            throw BackupError.multipleCompletionColumns
        }

        for task in envelope.tasks {
            guard PriorityCoordinate.approvedRange.contains(task.urgency),
                  PriorityCoordinate.approvedRange.contains(task.importance) else {
                throw BackupError.invalidCoordinate
            }
            if let projectID = task.projectID, !projectIDSet.contains(projectID) {
                throw BackupError.missingRelationship
            }
            if let columnID = task.boardColumnID, !columnIDSet.contains(columnID) {
                throw BackupError.missingRelationship
            }
            if !task.tagIDs.allSatisfy(tagIDSet.contains) {
                throw BackupError.missingRelationship
            }
            if let startAt = task.startAt, let dueAt = task.dueAt, startAt > dueAt {
                throw BackupError.invalidTimeRange
            }
        }

        for subtask in envelope.subtasks {
            guard taskIDSet.contains(subtask.taskID) else { throw BackupError.missingRelationship }
        }

        let subtaskIDSet = Set(subtaskIDs)
        for attachment in envelope.attachments {
            guard subtaskIDSet.contains(attachment.subtaskID) else { throw BackupError.missingRelationship }
        }

        var focusedTaskIDs = Set<UUID>()
        for entry in envelope.focusEntries {
            guard taskIDSet.contains(entry.taskID) else { throw BackupError.missingRelationship }
            guard TaskFocusState(rawValue: entry.stateRawValue) != nil else { throw BackupError.invalidFocusState }
            guard focusedTaskIDs.insert(entry.taskID).inserted else { throw BackupError.duplicateFocusEntry }
        }

        return envelope
    }

    public func applyImport(_ envelope: BackupEnvelope) throws {
        for existing in try context.fetch(FetchDescriptor<TaskItem>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<Project>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<Tag>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<BoardColumn>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<Subtask>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<SubtaskAttachment>()) { context.delete(existing) }
        for existing in try context.fetch(FetchDescriptor<FocusEntry>()) { context.delete(existing) }

        var projectsByID: [UUID: Project] = [:]
        for dto in envelope.projects {
            let project = Project(id: dto.id, name: dto.name, colorHex: dto.colorHex, createdAt: dto.createdAt)
            project.isArchived = dto.isArchived
            context.insert(project)
            projectsByID[dto.id] = project
        }

        var columnsByID: [UUID: BoardColumn] = [:]
        for dto in envelope.columns {
            let column = BoardColumn(id: dto.id, name: dto.name, order: dto.order, isCompletionColumn: dto.isCompletionColumn)
            column.project = projectsByID[dto.projectID]
            context.insert(column)
            columnsByID[dto.id] = column
        }

        var tagsByID: [UUID: Tag] = [:]
        for dto in envelope.tags {
            let tag = Tag(id: dto.id, name: dto.name, colorHex: dto.colorHex)
            context.insert(tag)
            tagsByID[dto.id] = tag
        }

        var tasksByID: [UUID: TaskItem] = [:]
        for dto in envelope.tasks {
            let task = TaskItem(id: dto.id, title: dto.title, now: dto.createdAt)
            task.details = dto.details
            task.startAt = dto.startAt
            task.urgency = dto.urgency
            task.importance = dto.importance
            task.dueAt = dto.dueAt
            task.reminderAt = dto.reminderAt
            task.estimatedMinutes = dto.estimatedMinutes
            task.isCompleted = dto.isCompleted
            task.completedAt = dto.completedAt
            task.previousBoardColumnID = dto.previousBoardColumnID
            task.manualOrder = dto.manualOrder
            task.createdAt = dto.createdAt
            task.updatedAt = dto.updatedAt
            if let projectID = dto.projectID {
                task.project = projectsByID[projectID]
            }
            if let columnID = dto.boardColumnID {
                task.boardColumn = columnsByID[columnID]
            }
            task.tags = dto.tagIDs.compactMap { tagsByID[$0] }
            context.insert(task)
            tasksByID[dto.id] = task
        }

        var subtasksByID: [UUID: Subtask] = [:]
        for dto in envelope.subtasks {
            let subtask = Subtask(id: dto.id, title: dto.title, order: dto.order, createdAt: dto.createdAt)
            subtask.isCompleted = dto.isCompleted
            subtask.task = tasksByID[dto.taskID]
            context.insert(subtask)
            subtasksByID[dto.id] = subtask
        }

        for dto in envelope.attachments {
            let attachment = SubtaskAttachment(
                id: dto.id,
                imageData: dto.imageData,
                thumbnailData: dto.thumbnailData,
                createdAt: dto.createdAt
            )
            attachment.subtask = subtasksByID[dto.subtaskID]
            context.insert(attachment)
        }

        for dto in envelope.focusEntries {
            guard let state = TaskFocusState(rawValue: dto.stateRawValue) else { continue }
            let entry = FocusEntry(id: dto.id, state: state, note: dto.note, now: dto.createdAt)
            entry.updatedAt = dto.updatedAt
            entry.task = tasksByID[dto.taskID]
            tasksByID[dto.taskID]?.focusEntry = entry
            context.insert(entry)
        }

        try context.save()
    }
}
