import XCTest
import TaskDomain
@testable import TaskApp

final class FocusPoolPresentationTests: XCTestCase {
    func testEveryFocusStateHasTheApprovedVisibleTitle() {
        XCTAssertEqual(FocusStatePresentation.title(for: .focused), "专注")
        XCTAssertEqual(FocusStatePresentation.title(for: .paused), "暂停")
        XCTAssertEqual(FocusStatePresentation.title(for: .blocked), "阻塞")
        XCTAssertEqual(FocusStatePresentation.title(for: .waiting), "等待")
    }
}
