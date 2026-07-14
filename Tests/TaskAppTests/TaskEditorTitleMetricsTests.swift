import AppKit
import XCTest
@testable import TaskApp

final class TaskEditorTitleMetricsTests: XCTestCase {
    func testLargeTitleFieldLeavesVerticalRoomForSystemFont() {
        let font = NSFont.systemFont(ofSize: 30, weight: .semibold)

        XCTAssertGreaterThanOrEqual(
            TaskEditorTitleMetrics.minimumFieldHeight,
            ceil(font.ascender - font.descender + font.leading) + 8
        )
    }
}
