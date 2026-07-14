import Foundation
import SwiftData

@MainActor
public final class TaskListLaneRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func defaultLanes() throws -> [BoardColumn] {
        let descriptor = FetchDescriptor<BoardColumn>(sortBy: [SortDescriptor(\.order)])
        let existing = try context.fetch(descriptor).filter { $0.project == nil }
        guard existing.isEmpty else { return existing }

        let lanes = [
            BoardColumn(name: "待规划", order: 0),
            BoardColumn(name: "本周计划", order: 1),
            BoardColumn(name: "进行中", order: 2),
            BoardColumn(name: "已完成", order: 3, isCompletionColumn: true),
        ]
        lanes.forEach(context.insert)
        try context.save()
        return lanes
    }
}
