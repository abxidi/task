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

    /// Pointer location expressed in the board's coordinate space.
    let boardLocation: CGPoint
    /// Pointer location relative to the dragged card's top-leading corner.
    let grabOffset: CGPoint
}

@MainActor
final class BoardDragCoordinator: ObservableObject {
    @Published private(set) var session: BoardDragSession?

    var taskID: UUID? { session?.taskID }
    var sourceColumnID: UUID? { session?.sourceColumnID }
    var targetColumnID: UUID? { session?.targetColumnID }

    /// Pointer location expressed in the board's coordinate space.
    var boardLocation: CGPoint? { session?.boardLocation }

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

    func finish() -> BoardDragMove? {
        defer { cancel() }

        guard
            let session,
            session.sourceColumnID != session.targetColumnID
        else {
            return nil
        }

        return BoardDragMove(taskID: session.taskID, targetColumnID: session.targetColumnID)
    }

    func cancel() {
        session = nil
    }
}
