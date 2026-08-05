import XCTest
@testable import TaskApp

final class SubtaskReorderPresentationTests: XCTestCase {
    @MainActor
    func testCompletingDragClearsInsertionPresentationBeforeReturningMove() {
        let sourceID = UUID()
        let middleID = UUID()
        let destinationID = UUID()
        let coordinator = SubtaskReorderCoordinator()
        let frames = [
            sourceID: CGRect(x: 0, y: 0, width: 320, height: 40),
            middleID: CGRect(x: 0, y: 48, width: 320, height: 40),
            destinationID: CGRect(x: 0, y: 96, width: 320, height: 40),
        ]

        coordinator.begin(sourceID: sourceID)
        coordinator.update(
            location: CGPoint(x: 100, y: 100),
            orderedIDs: [sourceID, middleID, destinationID],
            frames: frames
        )

        XCTAssertEqual(coordinator.insertionLocation, .before(destinationID))
        XCTAssertEqual(
            coordinator.complete(),
            SubtaskReorderMove(
                sourceID: sourceID,
                insertionLocation: .before(destinationID)
            )
        )
        XCTAssertNil(coordinator.session)
    }

    func testStableInsertionLocationDoesNotTriggerAnotherVisualUpdate() {
        let targetID = UUID()
        let location = SubtaskReorderInsertionLocation.before(targetID)

        XCTAssertFalse(
            SubtaskReorderPresentation.needsVisualUpdate(
                from: location,
                to: location
            )
        )
        XCTAssertTrue(
            SubtaskReorderPresentation.needsVisualUpdate(
                from: nil,
                to: location
            )
        )
    }
}
