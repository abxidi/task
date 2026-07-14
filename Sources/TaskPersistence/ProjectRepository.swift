import Foundation
import SwiftData

@MainActor
public final class ProjectRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createProject(name: String, colorHex: String) throws -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProjectRepositoryError.emptyName }
        let project = Project(name: trimmed, colorHex: colorHex)
        let columns = [
            BoardColumn(name: "待规划", order: 0),
            BoardColumn(name: "本周计划", order: 1),
            BoardColumn(name: "进行中", order: 2),
            BoardColumn(name: "已完成", order: 3, isCompletionColumn: true),
        ]
        columns.forEach { $0.project = project }
        project.boardColumns = columns
        context.insert(project)
        try context.save()
        return project
    }

    public func renameColumn(_ column: BoardColumn, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProjectRepositoryError.emptyName }
        column.name = trimmed
        try context.save()
    }

    public func reorderColumns(_ columns: [BoardColumn]) throws {
        for (index, column) in columns.enumerated() {
            column.order = index
        }
        try context.save()
    }

    public func addColumn(to project: Project, name: String) throws -> BoardColumn {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProjectRepositoryError.emptyName }
        let order = (project.boardColumns.map(\.order).max() ?? -1) + 1
        let column = BoardColumn(name: trimmed, order: order, isCompletionColumn: false)
        column.project = project
        project.boardColumns.append(column)
        context.insert(column)
        try context.save()
        return column
    }

    public func archiveColumn(_ column: BoardColumn) throws {
        guard !column.isCompletionColumn else { throw BoardWorkflowError.cannotArchiveCompletionColumn }
        guard let project = column.project else { return }
        let fallback = project.boardColumns
            .sorted { $0.order < $1.order }
            .first { !$0.isCompletionColumn && $0.id != column.id }
        for task in column.tasks {
            task.boardColumn = fallback
        }
        context.delete(column)
        try context.save()
    }
}

public enum ProjectRepositoryError: Error, Equatable {
    case emptyName
}
