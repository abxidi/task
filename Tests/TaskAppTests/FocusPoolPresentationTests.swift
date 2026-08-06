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

    func testFocusStatusControlUsesCompactSegmentedRailWithSeparateMarkers() {
        XCTAssertEqual(FocusPoolPresentation.statusControlWidth, 240)
        XCTAssertEqual(FocusPoolPresentation.statusSegmentWidth, 78)
        XCTAssertEqual(FocusPoolPresentation.statusControlHeight, 32)
        XCTAssertEqual(FocusPoolPresentation.statusSegmentHeight, 28)
        XCTAssertEqual(FocusPoolPresentation.selectedStatusMarkerSize, 11)
        XCTAssertEqual(FocusPoolPresentation.unselectedStatusMarkerSize, 11)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesNeutralSurface)
        XCTAssertTrue(FocusPoolPresentation.statusControlSeparatesMarkerAndTitle)
        XCTAssertTrue(FocusPoolPresentation.statusControlPlacesTitleAfterMarker)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesSegmentedRail)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesUniformMarkerSize)
        XCTAssertTrue(FocusPoolPresentation.selectedStatusMarkerUsesDotMatrix)
        XCTAssertEqual(FocusPoolPresentation.selectedStatusMarkerDotCount, 9)
        XCTAssertFalse(FocusPoolPresentation.statusControlUsesFilledStateBackground)
    }

    func testFocusStatusMarkerFillsOnlyTheSelectedState() {
        XCTAssertEqual(
            FocusPoolPresentation.markerStyle(isSelected: true),
            .filled
        )
        XCTAssertEqual(
            FocusPoolPresentation.markerStyle(isSelected: false),
            .hollow
        )
    }

    func testFocusCardsUseTwoColumnsAndPlainNoteField() {
        XCTAssertTrue(FocusPoolPresentation.usesTwoColumnCard)
        XCTAssertEqual(FocusPoolPresentation.subtaskColumnMinWidth, 280)
        XCTAssertTrue(FocusPoolPresentation.noteUsesPlainField)
        XCTAssertTrue(FocusPoolPresentation.noteUsesMultilineEditor)
        XCTAssertTrue(FocusPoolPresentation.subtasksUseCheckboxes)
        XCTAssertTrue(FocusPoolPresentation.subtasksSupportReordering)
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

    func testStatusControlAlignsWithTheNoteField() {
        XCTAssertEqual(FocusPoolPresentation.statusControlWidth, 240)
        XCTAssertEqual(FocusPoolPresentation.statusSegmentWidth, 78)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesLeadingAlignment)
        XCTAssertFalse(FocusPoolPresentation.statusControlUsesTrailingSpacer)
        XCTAssertFalse(FocusPoolPresentation.statusControlUsesNativePicker)
    }
}
