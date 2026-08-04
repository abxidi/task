import XCTest
@testable import TaskDomain

final class FocusStateTests: XCTestCase {
    func testApprovedStatesAppearInTrafficLightOrder() {
        XCTAssertEqual(TaskFocusState.allCases, [.focused, .waiting, .blocked])
    }

    func testLegacyPausedStateNormalizesToWaiting() {
        XCTAssertEqual(TaskFocusState(rawValue: "paused"), .waiting)
    }

    func testUnknownStateIsRejected() {
        XCTAssertNil(TaskFocusState(rawValue: "unknown"))
    }
}
