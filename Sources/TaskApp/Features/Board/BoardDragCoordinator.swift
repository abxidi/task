import Combine
import Foundation

struct BoardDragMove: Equatable {
    let taskID: UUID
    let targetColumnID: UUID
}

@MainActor
final class BoardDragCoordinator: ObservableObject {
    @Published private(set) var taskID: UUID?
    @Published private(set) var sourceColumnID: UUID?
    @Published private(set) var targetColumnID: UUID?
    @Published private(set) var location: CGPoint?

    func begin(taskID: UUID, sourceColumnID: UUID, location: CGPoint) {
        self.taskID = taskID
        self.sourceColumnID = sourceColumnID
        targetColumnID = sourceColumnID
        self.location = location
    }

    func update(location: CGPoint, targetColumnID: UUID) {
        guard taskID != nil else { return }

        self.location = location
        self.targetColumnID = targetColumnID
    }

    func finish() -> BoardDragMove? {
        defer { cancel() }

        guard
            let taskID,
            let sourceColumnID,
            let targetColumnID,
            sourceColumnID != targetColumnID
        else {
            return nil
        }

        return BoardDragMove(taskID: taskID, targetColumnID: targetColumnID)
    }

    func cancel() {
        taskID = nil
        sourceColumnID = nil
        targetColumnID = nil
        location = nil
    }
}
