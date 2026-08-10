import AppKit
import XCTest
@testable import TaskApp

final class SubtleScrollIndicatorStyleTests: XCTestCase {
    func testDisablesBothScrollers() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        TaskScrollIndicatorStyle.configure(scrollView)

        XCTAssertFalse(scrollView.hasVerticalScroller)
        XCTAssertFalse(scrollView.hasHorizontalScroller)
    }

    func testAlsoUsesSwiftUIIndicatorSuppression() {
        XCTAssertTrue(TaskScrollIndicatorStyle.hidesSwiftUIIndicators)
    }
}
