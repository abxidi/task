import Foundation
import XCTest
@testable import TaskApp

final class TaskDatePickerTests: XCTestCase {
    func testQuickChoicesUseCalendarAwareOffsets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let base = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2024,
            month: 1,
            day: 31,
            hour: 12,
            minute: 30
        )))

        XCTAssertEqual(
            TaskDateQuickChoice.twoHours.date(from: base, calendar: calendar),
            calendar.date(byAdding: .hour, value: 2, to: base)
        )
        XCTAssertEqual(
            TaskDateQuickChoice.oneMonth.date(from: base, calendar: calendar),
            calendar.date(byAdding: .month, value: 1, to: base)
        )
        XCTAssertEqual(
            TaskDateQuickChoice.sixMonths.date(from: base, calendar: calendar),
            calendar.date(byAdding: .month, value: 6, to: base)
        )
    }

    func testQuickChoicesMatchTheReferenceOrder() {
        XCTAssertEqual(
            TaskDateQuickChoice.allCases.map(\.title),
            ["两小时后", "八小时后", "一天后", "两天后", "一周后", "两周后", "一月后", "两月后", "半年后"]
        )
    }

    func testConfirmUsesTheTaskDateAsTheOptionalReminderTime() {
        let date = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(
            TaskDateCommit.confirmed(date: date, reminderEnabled: true),
            TaskDateCommit(dueAt: date, reminderAt: date)
        )
        XCTAssertEqual(
            TaskDateCommit.confirmed(date: date, reminderEnabled: false),
            TaskDateCommit(dueAt: date, reminderAt: nil)
        )
    }

    func testClearRemovesBothTaskDateAndReminder() {
        XCTAssertEqual(TaskDateCommit.cleared, TaskDateCommit(dueAt: nil, reminderAt: nil))
    }

    func testEndTimeCommitTargetsReminderAtTheEndOnly() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(
            TaskDateRangeCommit.confirmed(startAt: start, endAt: end, isEndReminderEnabled: true),
            TaskDateRangeCommit(startAt: start, dueAt: end, reminderAt: end)
        )
    }

    func testCompactCalendarUsesAStableSixWeekGrid() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 1
        let august = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))

        let days = TaskDateCalendarGrid.days(for: august, calendar: calendar)

        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(calendar.component(.month, from: days.first!), 7)
        XCTAssertEqual(calendar.component(.day, from: days.first!), 26)
        XCTAssertEqual(calendar.component(.month, from: days.last!), 9)
        XCTAssertEqual(calendar.component(.day, from: days.last!), 5)
    }
}
