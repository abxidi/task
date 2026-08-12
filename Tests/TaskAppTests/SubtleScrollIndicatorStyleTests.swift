import AppKit
import SwiftUI
import XCTest
@testable import TaskApp

final class SubtleScrollIndicatorStyleTests: XCTestCase {
    @MainActor
    func testInstalledPolicyRejectsLaterAttemptsToReenableScrollers() {
        TaskScrollIndicatorPolicy.install()
        let scrollView = NSScrollView()

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        XCTAssertFalse(scrollView.hasVerticalScroller)
        XCTAssertFalse(scrollView.hasHorizontalScroller)
    }

    @MainActor
    func testInstalledPolicyKeepsContentScrollable() {
        TaskScrollIndicatorPolicy.install()
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 1_000))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 240))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        XCTAssertEqual(scrollView.contentView.bounds.origin.y, 240)
        XCTAssertFalse(scrollView.hasVerticalScroller)
    }

    @MainActor
    func testInstalledPolicyKeepsHostedSwiftUIScrollViewsIndicatorFreeAcrossUpdates() {
        TaskScrollIndicatorPolicy.install()
        let hostingView = NSHostingView(rootView: scrollContent(rowCount: 80))
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 240)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView

        layoutAndDrainRunLoop(hostingView)
        assertAllScrollersAreDisabled(in: hostingView)

        hostingView.rootView = scrollContent(rowCount: 120)
        layoutAndDrainRunLoop(hostingView)
        assertAllScrollersAreDisabled(in: hostingView)
    }

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

    func testAppliesNativeScrollerSuppressionBeforeTheFirstFrame() {
        XCTAssertTrue(TaskScrollIndicatorStyle.appliesBeforeFirstFrame)
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

    @MainActor
    private func scrollContent(rowCount: Int) -> AnyView {
        AnyView(
            ScrollView(showsIndicators: true) {
                VStack {
                    ForEach(0..<rowCount, id: \.self) { row in
                        Text("Row \(row)")
                    }
                }
            }
        )
    }

    @MainActor
    private func layoutAndDrainRunLoop(_ hostingView: NSHostingView<AnyView>) {
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        hostingView.layoutSubtreeIfNeeded()
    }

    private func assertAllScrollersAreDisabled(
        in root: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let scrollViews = allScrollViews(in: root)
        XCTAssertFalse(scrollViews.isEmpty, file: file, line: line)
        for scrollView in scrollViews {
            XCTAssertFalse(scrollView.hasVerticalScroller, file: file, line: line)
            XCTAssertFalse(scrollView.hasHorizontalScroller, file: file, line: line)
        }
    }

    private func allScrollViews(in root: NSView) -> [NSScrollView] {
        let current = (root as? NSScrollView).map { [$0] } ?? []
        return current + root.subviews.flatMap(allScrollViews(in:))
    }

}
