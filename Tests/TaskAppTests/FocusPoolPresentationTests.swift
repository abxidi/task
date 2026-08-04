import XCTest
import TaskDomain
import TaskPersistence
@testable import TaskApp

final class FocusPoolPresentationTests: XCTestCase {
    func testEveryFocusStateHasTheApprovedVisibleTitle() {
        XCTAssertEqual(FocusStatePresentation.title(for: .focused), "专注")
        XCTAssertEqual(FocusStatePresentation.title(for: .paused), "暂停")
        XCTAssertEqual(FocusStatePresentation.title(for: .blocked), "阻塞")
        XCTAssertEqual(FocusStatePresentation.title(for: .waiting), "等待")
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

        XCTAssertEqual(tokens.map(\.rawValue), ["green", "blue", "red", "magenta"])
        XCTAssertEqual(Set(tokens).count, TaskFocusState.allCases.count)
    }

    func testCompletedTasksCannotBeAddedToFocusPool() {
        XCTAssertTrue(FocusPoolPresentation.canAddTask(isCompleted: false, hasFocusEntry: false))
        XCTAssertFalse(FocusPoolPresentation.canAddTask(isCompleted: true, hasFocusEntry: false))
        XCTAssertFalse(FocusPoolPresentation.canAddTask(isCompleted: false, hasFocusEntry: true))
    }

    func testIncompleteSubtasksAreShownInOriginalOrder() {
        let values = [
            FocusSubtaskItem(id: UUID(), title: "已完成", isCompleted: true),
            FocusSubtaskItem(id: UUID(), title: "先做", isCompleted: false),
            FocusSubtaskItem(id: UUID(), title: "后做", isCompleted: false),
        ]

        XCTAssertEqual(
            FocusPoolPresentation.incompleteSubtasks(from: values).map(\.title),
            ["先做", "后做"]
        )
    }

    func testFocusPoolUsesSharedPageAndCompactControlSizes() {
        XCTAssertEqual(FocusPoolPresentation.pageTitleFontSize, 26)
        XCTAssertEqual(FocusPoolPresentation.actionFontSize, 11)
        XCTAssertEqual(FocusPoolPresentation.taskTitleFontSize, 11)
        XCTAssertFalse(FocusPoolPresentation.showsStatusSymbol)
    }

    func testFocusCardsUseTwoColumnsAndPlainNoteField() {
        XCTAssertTrue(FocusPoolPresentation.usesTwoColumnCard)
        XCTAssertEqual(FocusPoolPresentation.subtaskColumnMinWidth, 280)
        XCTAssertTrue(FocusPoolPresentation.noteUsesPlainField)
        XCTAssertTrue(FocusPoolPresentation.subtasksUseCheckboxes)
    }

    func testStatusControlAlignsWithTheNoteField() {
        XCTAssertEqual(FocusPoolPresentation.statusControlWidth, 360)
        XCTAssertEqual(FocusPoolPresentation.statusSegmentWidth, 90)
        XCTAssertTrue(FocusPoolPresentation.statusControlUsesLeadingAlignment)
        XCTAssertFalse(FocusPoolPresentation.statusControlUsesTrailingSpacer)
        XCTAssertFalse(FocusPoolPresentation.statusControlUsesNativePicker)
    }
}
