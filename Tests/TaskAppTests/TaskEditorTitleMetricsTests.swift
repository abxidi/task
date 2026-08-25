import AppKit
import SwiftUI
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

    func testSubtaskRowContentIsVerticallyCentered() {
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.rowContentAlignment, .center)
    }

    func testSubtaskRowUsesTheCenteredAlignmentContract() throws {
        let workspaceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let editorURL = workspaceURL.appending(path: "Sources/TaskApp/Features/TaskEditor/SubtaskEditor.swift")
        let source = try String(contentsOf: editorURL)

        XCTAssertTrue(source.contains("HStack(alignment: TaskEditorSubtaskEntryStyle.rowContentAlignment, spacing: 8)"))
    }

    func testTaskEditorProvidesTopAndBottomSubtaskEntryPoints() {
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsTopEntry(forSubtaskCount: 1))
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsBottomEntry(forSubtaskCount: 1))
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.topEntryAccessibilityLabel, "从上方添加子任务")
        XCTAssertEqual(
            TaskEditorSubtaskEntryStyle.bottomEntryAccessibilityLabel(forSubtaskCount: 1),
            "从下方添加子任务"
        )
    }

    func testTaskEditorShowsOneEntryWhenThereAreNoSubtasks() {
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.entryCount(forSubtaskCount: 0), 1)
        XCTAssertFalse(TaskEditorSubtaskEntryStyle.showsTopEntry(forSubtaskCount: 0))
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsBottomEntry(forSubtaskCount: 0))
        XCTAssertEqual(
            TaskEditorSubtaskEntryStyle.bottomEntryAccessibilityLabel(forSubtaskCount: 0),
            "添加子任务"
        )
    }

    func testTaskEditorShowsTwoEntriesWhenSubtasksExist() {
        XCTAssertEqual(TaskEditorSubtaskEntryStyle.entryCount(forSubtaskCount: 1), 2)
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsTopEntry(forSubtaskCount: 1))
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsBottomEntry(forSubtaskCount: 1))
    }

    func testTaskListSubtaskTitlesUseUnboundedMultilineText() {
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.subtaskTitlesUseMultilineField)
        XCTAssertNil(TaskEditorSubtaskEntryStyle.subtaskTitleMaximumLineCount)
    }

    func testAddedSubtasksUseTheUnnestedEditorRows() {
        XCTAssertFalse(TaskEditorSubtaskEntryStyle.usesSharedListRows)
    }

    func testTaskEditorSubtaskReorderingShowsInsertionIndicatorAtListEnd() {
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.showsReorderInsertionIndicator)
        XCTAssertTrue(TaskEditorSubtaskEntryStyle.supportsEndDropInsertion)
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

    func testQuickEditorUsesAnAdaptiveNoteInsteadOfFocusDrivenExpansion() {
        XCTAssertTrue(TaskEditorLayout.usesAdaptiveNoteHeight)
        XCTAssertEqual(TaskEditorLayout.noteMinimumHeight, 32)
        XCTAssertEqual(TaskEditorLayout.noteMaximumHeight, 112)
        XCTAssertFalse(TaskEditorLayout.expandsNoteOnlyForFocus)
    }

    func testTaskEditorUsesOnePanelSizeAcrossPresentationEntrypoints() {
        let fullWindow = TaskEditorOverlayLayout.panelSize(
            for: CGSize(width: 1900, height: 1100),
            subtaskCount: 0
        )
        let contentArea = TaskEditorOverlayLayout.panelSize(
            for: CGSize(width: 1500, height: 1100),
            subtaskCount: 0
        )

        XCTAssertEqual(fullWindow, CGSize(width: 1040, height: 360))
        XCTAssertEqual(contentArea, fullWindow)
    }

    func testTaskEditorHeightGrowsPerSubtaskAndCapsAtEightyEightPercent() {
        let availableSize = CGSize(width: 1900, height: 1000)

        XCTAssertEqual(
            TaskEditorOverlayLayout.panelSize(for: availableSize, subtaskCount: 3).height,
            483
        )
        XCTAssertEqual(
            TaskEditorOverlayLayout.panelSize(for: availableSize, subtaskCount: 20).height,
            880
        )
    }

    func testEditorHeightIncludesAdditionalVisibleNoteLines() {
        let compact = TaskEditorOverlayLayout.panelSize(
            for: CGSize(width: 1900, height: 1000),
            subtaskCount: 0,
            noteHeight: TaskEditorNoteLayout.minimumHeight
        )
        let fiveLines = TaskEditorOverlayLayout.panelSize(
            for: CGSize(width: 1900, height: 1000),
            subtaskCount: 0,
            noteHeight: TaskEditorNoteLayout.maximumHeight
        )

        XCTAssertEqual(compact.height, 360)
        XCTAssertEqual(fiveLines.height, 440)
    }

    func testTaskEditorSupportsEscapeToClose() {
        XCTAssertTrue(TaskEditorOverlayLayout.supportsEscapeToClose)
        XCTAssertTrue(TaskEditorLayout.supportsEscapeToClose)
    }

    @MainActor
    func testTaskEditorCoordinatorOwnsOneWindowLevelPresentation() {
        let coordinator = TaskEditorPresentationCoordinator()

        XCTAssertNil(coordinator.mode)
        coordinator.present(.create)
        XCTAssertNotNil(coordinator.mode)
        coordinator.dismiss()
        XCTAssertNil(coordinator.mode)
    }
}
