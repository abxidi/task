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

    func testConfiguresEveryScrollerInTheWindowHierarchy() {
        let root = NSView()
        let outerScroller = NSScrollView()
        let nestedContainer = NSView()
        let innerScroller = NSScrollView()
        outerScroller.hasVerticalScroller = true
        innerScroller.hasHorizontalScroller = true
        nestedContainer.addSubview(innerScroller)
        root.addSubview(outerScroller)
        root.addSubview(nestedContainer)

        TaskScrollIndicatorStyle.configureAllScrollViews(in: root)

        XCTAssertFalse(outerScroller.hasVerticalScroller)
        XCTAssertFalse(innerScroller.hasHorizontalScroller)
    }
}
