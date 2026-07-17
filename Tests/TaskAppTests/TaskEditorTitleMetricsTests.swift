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

    func testEditorUsesInlineMetadataAndPriorityPopoverInsteadOfSettingsEntry() {
        XCTAssertTrue(TaskEditorLayout.usesInlineMetadata)
        XCTAssertFalse(TaskEditorLayout.showsTaskSettingsEntry)
        XCTAssertTrue(TaskEditorLayout.usesAutomaticSave)
        XCTAssertFalse(TaskEditorLayout.showsSaveButton)
        XCTAssertFalse(TaskEditorLayout.showsCancelButton)
    }

    func testEmptyEditorUsesCompactWritingSurface() {
        XCTAssertEqual(TaskEditorLayout.titleContentWidth, 460)
        XCTAssertEqual(TaskEditorLayout.emptySubtaskHeight, 40)
    }

    func testEmptySubtaskStartsWithTheCompactInputStyle() {
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.startsAsInput)
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.iconSize, 12)
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.iconFrameSize, 18)
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.minimumHeight, 40)
    }

    func testAddedSubtasksAlignWithTheNewSubtaskIcon() {
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.usesSharedListRows)
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.listRowLeadingInset, 10)
    }

    func testPriorityEntryUsesNormalAndHighPriorityLabels() {
        XCTAssertEqual(TaskEditorPriorityLabel.title(for: .init(uncheckedUrgency: 0, importance: 0)), "正常")
        XCTAssertEqual(TaskEditorPriorityLabel.title(for: .init(uncheckedUrgency: 2, importance: 3)), "高优")
    }

    func testEditorPlaceholdersHideWhenTheirFieldReceivesFocus() {
        XCTAssertTrue(TaskEditorPlaceholder.isVisible(text: "", isFocused: false))
        XCTAssertFalse(TaskEditorPlaceholder.isVisible(text: "", isFocused: true))
        XCTAssertFalse(TaskEditorPlaceholder.isVisible(text: "已输入", isFocused: false))
    }

    func testEditorPlaceholdersUseReducedEmphasis() {
        XCTAssertLessThan(TaskEditorPlaceholder.opacity, 1)
    }

    func testTaskEditorUsesOnePanelSizeAcrossPresentationEntrypoints() {
        let fullWindow = TaskEditorOverlayLayout.panelSize(for: CGSize(width: 1900, height: 1100))
        let contentArea = TaskEditorOverlayLayout.panelSize(for: CGSize(width: 1500, height: 1100))

        XCTAssertEqual(fullWindow, CGSize(width: 1040, height: 720))
        XCTAssertEqual(contentArea, fullWindow)
    }

    func testTaskEditorSupportsEscapeToClose() {
        XCTAssertTrue(TaskEditorOverlayLayout.supportsEscapeToClose)
    }
}
