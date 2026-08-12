import AppKit
import SwiftUI
import XCTest
@testable import TaskApp

final class SubtleScrollIndicatorStyleTests: XCTestCase {
    @MainActor
    func testInstalledPolicyPreservesNativeScrollerState() {
        TaskScrollIndicatorPolicy.install()
        let scrollView = NSScrollView()

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        XCTAssertTrue(scrollView.hasVerticalScroller)
        XCTAssertTrue(scrollView.hasHorizontalScroller)
    }

    @MainActor
    func testInstalledPolicySuppressesScrollerRenderingWithoutRemovingIt() throws {
        TaskScrollIndicatorPolicy.install()
        let scroller = NSScroller(frame: NSRect(x: 0, y: 0, width: 16, height: 120))
        scroller.scrollerStyle = .legacy
        scroller.doubleValue = 0.4
        scroller.knobProportion = 0.2
        let representation = try XCTUnwrap(
            scroller.bitmapImageRepForCachingDisplay(in: scroller.bounds)
        )

        scroller.cacheDisplay(in: scroller.bounds, to: representation)

        let pixels = try XCTUnwrap(representation.bitmapData)
        let byteCount = representation.bytesPerRow * representation.pixelsHigh
        XCTAssertEqual(UnsafeBufferPointer(start: pixels, count: byteCount).filter { $0 != 0 }.count, 0)
    }

    @MainActor
    func testInstalledPolicyKeepsScrollerTransparentWhenAppKitTriesToRevealIt() {
        TaskScrollIndicatorPolicy.install()
        let scroller = NSScroller()
        let ordinaryView = NSView()

        scroller.alphaValue = 1
        ordinaryView.alphaValue = 0.6

        XCTAssertEqual(scroller.alphaValue, 0)
        XCTAssertEqual(ordinaryView.alphaValue, 0.6)
    }

    @MainActor
    func testInstalledPolicyKeepsContentScrollable() {
        TaskScrollIndicatorPolicy.install()
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        scrollView.hasVerticalScroller = true
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 1_000))

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 240))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        XCTAssertEqual(scrollView.contentView.bounds.origin.y, 240)
        XCTAssertEqual(scrollView.contentView.bounds.origin.x, 0)
        XCTAssertTrue(scrollView.hasVerticalScroller)
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
        assertAllScrollViewsPreserveGeometry(in: hostingView)

        hostingView.rootView = scrollContent(rowCount: 120)
        layoutAndDrainRunLoop(hostingView)
        assertAllScrollViewsPreserveGeometry(in: hostingView)
    }

    func testConfiguringIndicatorsDoesNotChangeScrollViewGeometry() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        let originalContentSize = scrollView.contentSize

        TaskScrollIndicatorStyle.configure(scrollView)

        XCTAssertTrue(scrollView.hasVerticalScroller)
        XCTAssertTrue(scrollView.hasHorizontalScroller)
        XCTAssertEqual(scrollView.verticalScroller?.alphaValue, 0)
        XCTAssertEqual(scrollView.horizontalScroller?.alphaValue, 0)
        XCTAssertEqual(scrollView.contentSize, originalContentSize)
    }

    @MainActor
    func testConfiguredScrollViewRejectsLegacyStyleThatWouldConsumeContentWidth() {
        TaskScrollIndicatorPolicy.install()
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        scrollView.hasVerticalScroller = true
        TaskScrollIndicatorStyle.configure(scrollView)
        let originalContentWidth = scrollView.contentSize.width

        scrollView.scrollerStyle = .legacy
        scrollView.tile()

        XCTAssertEqual(scrollView.scrollerStyle, .overlay)
        XCTAssertEqual(scrollView.contentSize.width, originalContentWidth)
    }

    func testAlsoUsesSwiftUIIndicatorSuppression() {
        XCTAssertTrue(TaskScrollIndicatorStyle.hidesSwiftUIIndicators)
    }

    func testAppliesNativeScrollerSuppressionBeforeTheFirstFrame() {
        XCTAssertTrue(TaskScrollIndicatorStyle.appliesBeforeFirstFrame)
    }

    func testHostPreservesEnclosingScrollerGeometryWhenItJoinsTheHierarchy() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        let host = TaskScrollIndicatorHostView()

        scrollView.documentView = host

        XCTAssertTrue(scrollView.hasVerticalScroller)
        XCTAssertTrue(scrollView.hasHorizontalScroller)
    }

    func testConfigureAllScrollViewsPreservesNestedScrollerGeometry() {
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

        XCTAssertTrue(outer.hasVerticalScroller)
        XCTAssertTrue(outer.hasHorizontalScroller)
        XCTAssertTrue(inner.hasVerticalScroller)
        XCTAssertTrue(inner.hasHorizontalScroller)
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

    private func assertAllScrollViewsPreserveGeometry(
        in root: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let scrollViews = allScrollViews(in: root)
        XCTAssertFalse(scrollViews.isEmpty, file: file, line: line)
        for scrollView in scrollViews {
            let contentWidth = scrollView.contentSize.width
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 40))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            XCTAssertEqual(scrollView.contentView.bounds.origin.x, 0, file: file, line: line)
            XCTAssertEqual(scrollView.contentSize.width, contentWidth, file: file, line: line)
        }
    }

    private func allScrollViews(in root: NSView) -> [NSScrollView] {
        let current = (root as? NSScrollView).map { [$0] } ?? []
        return current + root.subviews.flatMap(allScrollViews(in:))
    }

}
