import AppKit
import XCTest
@testable import TaskApp

final class SubtleScrollIndicatorStyleTests: XCTestCase {
    func testConfiguresOverlayAutoHidingSmallScrollers() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        TaskScrollIndicatorStyle.configure(scrollView)

        XCTAssertEqual(scrollView.scrollerStyle, .overlay)
        XCTAssertTrue(scrollView.autohidesScrollers)
        XCTAssertEqual(scrollView.verticalScroller?.controlSize, .small)
        XCTAssertEqual(scrollView.horizontalScroller?.controlSize, .small)
    }
}
