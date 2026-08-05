import Foundation
import SwiftUI

enum SubtaskReorderPresentation {
    static let insertionIndicatorHeight: CGFloat = 2
    static let insertionIndicatorUsesSystemBlue = true
    static let dragMinimumDistance: CGFloat = 3
    static let sourceOpacity = 0.35
    static let reorderDuration = 0.14

    static var handoffTransaction: Transaction {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return transaction
    }

    static func needsVisualUpdate(
        from previous: SubtaskReorderInsertionLocation?,
        to next: SubtaskReorderInsertionLocation?
    ) -> Bool {
        previous != next
    }

    static func insertionLocation(
        for location: CGPoint,
        sourceID: UUID,
        orderedIDs: [UUID],
        frames: [UUID: CGRect]
    ) -> SubtaskReorderInsertionLocation? {
        let destinations = orderedIDs.filter { $0 != sourceID && frames[$0] != nil }
        guard let firstID = destinations.first,
              let lastID = destinations.last,
              let firstFrame = frames[firstID],
              let lastFrame = frames[lastID],
              location.y >= firstFrame.minY - 12,
              location.y <= lastFrame.maxY + 12 else {
            return nil
        }

        for id in destinations {
            guard let frame = frames[id] else { continue }
            if location.y < frame.midY {
                return .before(id)
            }
        }
        return .after(lastID)
    }
}

enum SubtaskReorderInsertionLocation: Equatable {
    case before(UUID)
    case after(UUID)
}

struct SubtaskReorderMove: Equatable {
    let sourceID: UUID
    let insertionLocation: SubtaskReorderInsertionLocation
}

struct SubtaskReorderSession: Equatable {
    let sourceID: UUID
    let insertionLocation: SubtaskReorderInsertionLocation?
}

struct SubtaskReorderFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

@MainActor
final class SubtaskReorderCoordinator: ObservableObject {
    @Published private(set) var session: SubtaskReorderSession?

    var sourceID: UUID? { session?.sourceID }
    var insertionLocation: SubtaskReorderInsertionLocation? { session?.insertionLocation }

    func begin(sourceID: UUID) {
        session = SubtaskReorderSession(sourceID: sourceID, insertionLocation: nil)
    }

    func update(location: CGPoint, orderedIDs: [UUID], frames: [UUID: CGRect]) {
        guard let session else { return }
        let insertionLocation = SubtaskReorderPresentation.insertionLocation(
            for: location,
            sourceID: session.sourceID,
            orderedIDs: orderedIDs,
            frames: frames
        )
        guard SubtaskReorderPresentation.needsVisualUpdate(
            from: session.insertionLocation,
            to: insertionLocation
        ) else {
            return
        }
        self.session = SubtaskReorderSession(
            sourceID: session.sourceID,
            insertionLocation: insertionLocation
        )
    }

    func complete() -> SubtaskReorderMove? {
        guard let session else { return nil }
        withTransaction(SubtaskReorderPresentation.handoffTransaction) {
            self.session = nil
        }
        guard let insertionLocation = session.insertionLocation else { return nil }
        return SubtaskReorderMove(
            sourceID: session.sourceID,
            insertionLocation: insertionLocation
        )
    }

    func cancel() {
        withTransaction(SubtaskReorderPresentation.handoffTransaction) {
            session = nil
        }
    }
}

struct SubtaskReorderInsertionIndicator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .systemBlue))
            .frame(maxWidth: .infinity)
            .frame(height: SubtaskReorderPresentation.insertionIndicatorHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
