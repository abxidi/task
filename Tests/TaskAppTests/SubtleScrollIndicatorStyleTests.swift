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

    func testHostDisablesEnclosingScrollersWhenItJoinsTheHierarchy() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        let host = TaskScrollIndicatorHostView()

        scrollView.documentView = host

        XCTAssertFalse(scrollView.hasVerticalScroller)
        XCTAssertFalse(scrollView.hasHorizontalScroller)
    }

    func testConfigureAllScrollViewsDisablesNestedScrollers() {
        let root = NSView()
        let outer = NSScrollView()
        let container = NSView()
        let inner = NSScrollView()
        outer.hasVerticalScroller = true
        outer.hasHorizontalScroller = true
        inner.hasVerticalScroller = true
        inner.hasHorizontalScroller = true

        root.addSubview(outer)
        outer.documentView = container
        container.addSubview(inner)

        TaskScrollIndicatorStyle.configureAllScrollViews(in: root)

        XCTAssertFalse(outer.hasVerticalScroller)
        XCTAssertFalse(outer.hasHorizontalScroller)
        XCTAssertFalse(inner.hasVerticalScroller)
        XCTAssertFalse(inner.hasHorizontalScroller)
    }

}
