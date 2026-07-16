import Combine
import Foundation

struct BoardDragMove: Equatable {
    let taskID: UUID
    let targetColumnID: UUID
}

struct BoardDragSession: Equatable {
    let taskID: UUID
    let sourceColumnID: UUID
    let targetColumnID: UUID
    let boardLocation: CGPoint
    let grabOffset: CGPoint
}

@MainActor
final class BoardDragCoordinator: ObservableObject {
    @Published private(set) var session: BoardDragSession?

    var taskID: UUID? { session?.taskID }
    var sourceColumnID: UUID? { session?.sourceColumnID }
    var targetColumnID: UUID? { session?.targetColumnID }
    var boardLocation: CGPoint? { session?.boardLocation }
    var location: CGPoint? { session?.boardLocation }

    func begin(
        taskID: UUID,
        sourceColumnID: UUID,
        boardLocation: CGPoint,
        grabOffset: CGPoint = .zero
    ) {
        session = BoardDragSession(
            taskID: taskID,
            sourceColumnID: sourceColumnID,
            targetColumnID: sourceColumnID,
            boardLocation: boardLocation,
            grabOffset: grabOffset
        )
    }

    func begin(taskID: UUID, sourceColumnID: UUID, location: CGPoint) {
        begin(taskID: taskID, sourceColumnID: sourceColumnID, boardLocation: location)
    }

    func update(boardLocation: CGPoint, targetColumnID: UUID) {
        guard let session else { return }
        self.session = BoardDragSession(
            taskID: session.taskID,
            sourceColumnID: session.sourceColumnID,
            targetColumnID: targetColumnID,
            boardLocation: boardLocation,
            grabOffset: session.grabOffset
        )
    }

    func update(location: CGPoint, targetColumnID: UUID?) {
        guard let targetColumnID else { return }
        update(boardLocation: location, targetColumnID: targetColumnID)
    }

    func finish() -> BoardDragMove? {
        defer { cancel() }
        guard let session, session.sourceColumnID != session.targetColumnID else {
            return nil
        }
        return BoardDragMove(taskID: session.taskID, targetColumnID: session.targetColumnID)
    }

    func cancel() {
        session = nil
    }
}
