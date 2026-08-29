import XCTest
import TaskDomain
import TaskPersistence
@testable import TaskApp

final class FocusPoolPresentationTests: XCTestCase {
    func testFocusPoolPageTitleMatchesTheSidebarTitle() {
        XCTAssertEqual(FocusPoolPresentation.pageTitle, "正在进行")
        XCTAssertEqual(FocusPoolPresentation.pageTitle, AppRoute.focusPool.sidebarTitle)
    }

    func testEveryFocusStateHasTheApprovedVisibleTitle() {
        XCTAssertEqual(FocusStatePresentation.title(for: .focused), "专注")
        XCTAssertEqual(FocusStatePresentation.title(for: .waiting), "等待")
        XCTAssertEqual(FocusStatePresentation.title(for: .blocked), "阻塞")
    }

    func testFocusPoolSortsEntriesByTaskPriority() {
        let now = Date(timeIntervalSince1970: 1_000)
        let lowerPriority = TaskItem(title: "普通任务", now: now)
        lowerPriority.importance = 1
        lowerPriority.urgency = 3

        let middlePriority = TaskItem(title: "重要任务", now: now)
        middlePriority.importance = 3
        middlePriority.urgency = 1

        let highestPriority = TaskItem(title: "最优先任务", now: now)
        highestPriority.importance = 3
        highestPriority.urgency = 3

        XCTAssertEqual(
            [lowerPriority, highestPriority, middlePriority]
                .sorted(by: FocusPoolPresentation.sortsByTaskPriority)
                .map(\.title),
            ["最优先任务", "重要任务", "普通任务"]
        )
    }

    func testFocusStatesUseDistinctSelectionColors() {
        let tokens = TaskFocusState.allCases.map(FocusStatePresentation.selectionColorToken)

        XCTAssertEqual(tokens.map(\.rawValue), ["green", "yellow", "red"])
        XCTAssertEqual(Set(tokens).count, TaskFocusState.allCases.count)
        XCTAssertTrue(FocusStatePresentation.usesDarkSelectionText(for: .waiting))
        XCTAssertFalse(FocusStatePresentation.usesDarkSelectionText(for: .focused))
        XCTAssertFalse(FocusStatePresentation.usesDarkSelectionText(for: .blocked))
    }

    func testFocusStatesUseTheSignalLightReferencePalette() {
        XCTAssertEqual(FocusStateColorToken.green.signalLightHex, 0x35D6B5)
        XCTAssertEqual(FocusStateColorToken.yellow.signalLightHex, 0xF2C440)
        XCTAssertEqual(FocusStateColorToken.red.signalLightHex, 0xEF5058)
    }

    func testCompletedTasksCannotBeAddedToFocusPool() {
        XCTAssertTrue(FocusPoolPresentation.canAddTask(isCompleted: false, hasFocusEntry: false))
        XCTAssertFalse(FocusPoolPresentation.canAddTask(isCompleted: true, hasFocusEntry: false))
        XCTAssertFalse(FocusPoolPresentation.canAddTask(isCompleted: false, hasFocusEntry: true))
    }

    func testFocusPoolHidesCompletedSubtasksWithoutReorderingTheRemainingItems() {
        let values = [
            FocusSubtaskItem(id: UUID(), title: "已完成", isCompleted: true),
            FocusSubtaskItem(id: UUID(), title: "先做", isCompleted: false),
            FocusSubtaskItem(id: UUID(), title: "后做", isCompleted: false),
        ]

        XCTAssertEqual(
            FocusPoolPresentation.subtasks(from: values).map(\.title),
            ["先做", "后做"]
        )
    }

    func testFocusPoolUsesSharedPageAndCompactControlSizes() {
        XCTAssertEqual(FocusPoolPresentation.pageTitleFontSize, 26)
        XCTAssertEqual(FocusPoolPresentation.actionFontSize, 11)
        XCTAssertEqual(FocusPoolPresentation.taskTitleFontSize, 11)
        XCTAssertFalse(FocusPoolPresentation.showsStatusSymbol)
    }

    func testFocusSubtaskTitlesUseUnboundedMultilineText() {
        XCTAssertTrue(FocusPoolPresentation.subtaskTitlesUseMultilineField)
        XCTAssertNil(FocusPoolPresentation.subtaskTitleMaximumLineCount)
    }

    func testFocusSubtaskTitlesUseTaskEditorFontSize() {
        XCTAssertEqual(FocusPoolPresentation.subtaskTitleFontSize, 12)
    }

    func testFocusSubtaskTitleUsesAStableCenteredRowHeight() throws {
        XCTAssertEqual(FocusPoolPresentation.subtaskRowMinimumHeight, 36)

        let workspaceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = workspaceURL.appending(path: "Sources/TaskApp/Features/FocusPoolScreen.swift")
        let source = try String(contentsOf: sourceURL)
        let titleEditorSource = try XCTUnwrap(
            source.components(separatedBy: "private struct FocusSubtaskTitleEditor: View").last
        )

        XCTAssertTrue(titleEditorSource.contains("minHeight: FocusPoolPresentation.subtaskRowMinimumHeight"))
        XCTAssertTrue(titleEditorSource.contains("alignment: .center"))
    }

    func testFocusStatusAndNoteUseASingleRowWithNativeDropdown() {
        XCTAssertTrue(FocusPoolPresentation.statusDetailsUseSingleRow)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesNativePicker)
        XCTAssertTrue(FocusPoolPresentation.statusNoteUsesMultilineField)
        XCTAssertEqual(FocusPoolPresentation.statusPickerWidth, 80)
        XCTAssertEqual(FocusPoolPresentation.statusDetailsSpacing, 4)
    }

    func testFocusStatusNoteWrapsLongInput() throws {
        let workspaceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = workspaceURL.appending(path: "Sources/TaskApp/Features/FocusPoolScreen.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("TextField(\"添加备注\", text: $note, axis: .vertical)"))
        XCTAssertTrue(source.contains(".lineLimit(1...FocusPoolPresentation.statusNoteMaximumLineCount)"))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    func testFocusCardsUseLinkedSubtaskRows() {
        XCTAssertTrue(FocusPoolPresentation.usesLinkedSubtaskRows)
        XCTAssertTrue(FocusPoolPresentation.linkedRowsShareVerticalAlignment)
        XCTAssertTrue(FocusPoolPresentation.linkedRowsCenterContentVertically)
        XCTAssertTrue(FocusPoolPresentation.linkedRowsUseCenterConnectionMarker)
        XCTAssertTrue(FocusPoolPresentation.subtasksUseCheckboxes)
        XCTAssertTrue(FocusPoolPresentation.subtasksSupportReordering)
    }

    func testFocusSubtaskContentUsesCenteredVerticalAlignment() throws {
        let workspaceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = workspaceURL.appending(path: "Sources/TaskApp/Features/FocusPoolScreen.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("HStack(alignment: .center, spacing: 8)"))
        XCTAssertTrue(source.contains("anchor: .center"))
    }

    func testFocusSubtaskRowsUseEqualLinkedColumns() throws {
        let widths = try XCTUnwrap(FocusPoolPresentation.linkedRowColumnWidths(for: 800))

        XCTAssertEqual(FocusPoolPresentation.linkedRowLeftRatio, 0.5, accuracy: 0.000_1)
        XCTAssertEqual(FocusPoolPresentation.linkedRowRightRatio, 0.5, accuracy: 0.000_1)
        XCTAssertEqual(widths.left, widths.right, accuracy: 0.000_1)
        XCTAssertEqual(FocusPoolPresentation.linkedRowDividerWidth, 1)
    }

    func testFocusLinkedRowsStackBelowTheTwoColumnMinimumWidth() throws {
        let widths = try XCTUnwrap(
            FocusPoolPresentation.linkedRowColumnWidths(
                for: FocusPoolPresentation.minimumLinkedRowWidth
            )
        )

        XCTAssertEqual(widths.left, FocusPoolPresentation.linkedRowMinimumColumnWidth, accuracy: 0.000_1)
        XCTAssertEqual(widths.right, FocusPoolPresentation.linkedRowMinimumColumnWidth, accuracy: 0.000_1)
        XCTAssertNil(
            FocusPoolPresentation.linkedRowColumnWidths(
                for: FocusPoolPresentation.minimumLinkedRowWidth - 1
            )
        )
    }

    func testFocusSubtaskStatusIsHiddenUntilStarted() {
        XCTAssertFalse(FocusPoolPresentation.showsSubtaskFocusDetails(state: nil))
        XCTAssertTrue(FocusPoolPresentation.showsSubtaskFocusDetails(state: .focused))
    }

    func testFocusLinkedRowWidthsRemainUnsetUntilTheCardHasFiniteWidth() {
        XCTAssertNil(FocusPoolPresentation.linkedRowColumnWidths(for: 0))
        XCTAssertNil(FocusPoolPresentation.linkedRowColumnWidths(for: .infinity))
    }

    func testFocusSubtaskReorderingUsesSystemBlueInsertionIndicator() {
        XCTAssertTrue(FocusPoolPresentation.subtasksShowInsertionIndicator)
        XCTAssertEqual(SubtaskReorderPresentation.insertionIndicatorHeight, 2)
        XCTAssertTrue(SubtaskReorderPresentation.insertionIndicatorUsesSystemBlue)
    }

    func testSubtaskCompletionCanOnlyBeTriggeredByItsCheckbox() {
        XCTAssertTrue(FocusPoolPresentation.allowsSubtaskCompletion(from: .checkbox))
        XCTAssertFalse(FocusPoolPresentation.allowsSubtaskCompletion(from: .title))
    }

    func testStatusDropdownRetainsTheApprovedStateColors() {
        XCTAssertEqual(
            TaskFocusState.allCases.map(FocusStatePresentation.selectionColorToken).map(\.rawValue),
            ["green", "yellow", "red"]
        )
    }
}
