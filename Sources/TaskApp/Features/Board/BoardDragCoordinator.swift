import Combine
import Foundation

struct BoardDragMove: Equatable {
    let taskID: UUID
    let targetColumnID: UUID
}

enum BoardDragPhase: Equatable {
    case dragging
    case settling
}

struct BoardDragSession: Equatable {
    let taskID: UUID
    let sourceColumnID: UUID
    let targetColumnID: UUID
    let boardLocation: CGPoint
    let sourceFrame: CGRect
    let grabOffset: CGPoint
    let phase: BoardDragPhase

    init(
        taskID: UUID,
        sourceColumnID: UUID,
        targetColumnID: UUID,
        boardLocation: CGPoint,
        grabOffset: CGPoint,
        sourceFrame: CGRect = .zero,
        phase: BoardDragPhase = .dragging
    ) {
        self.taskID = taskID
        self.sourceColumnID = sourceColumnID
        self.targetColumnID = targetColumnID
        self.boardLocation = boardLocation
        self.sourceFrame = sourceFrame
        self.grabOffset = grabOffset
        self.phase = phase
    }
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
        sourceFrame: CGRect = .zero,
        grabOffset: CGPoint = .zero
    ) {
        session = BoardDragSession(
            taskID: taskID,
            sourceColumnID: sourceColumnID,
            targetColumnID: sourceColumnID,
            boardLocation: boardLocation,
            grabOffset: grabOffset,
            sourceFrame: sourceFrame
        )
    }

    func begin(taskID: UUID, sourceColumnID: UUID, location: CGPoint) {
        begin(taskID: taskID, sourceColumnID: sourceColumnID, boardLocation: location)
    }

    func update(boardLocation: CGPoint, targetColumnID: UUID) {
        guard let session, session.phase == .dragging else { return }
        self.session = BoardDragSession(
            taskID: session.taskID,
            sourceColumnID: session.sourceColumnID,
            targetColumnID: targetColumnID,
            boardLocation: boardLocation,
            grabOffset: session.grabOffset,
            sourceFrame: session.sourceFrame
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

    func settle(to destinationFrame: CGRect) {
        guard let session, session.phase == .dragging else { return }
        self.session = BoardDragSession(
            taskID: session.taskID,
            sourceColumnID: session.sourceColumnID,
            targetColumnID: session.targetColumnID,
            boardLocation: CGPoint(
                x: destinationFrame.minX + session.grabOffset.x,
                y: destinationFrame.minY + session.grabOffset.y
            ),
            grabOffset: session.grabOffset,
            sourceFrame: session.sourceFrame,
            phase: .settling
        )
    }

    func complete() {
        cancel()
    }

    func cancel() {
        session = nil
    }
}
