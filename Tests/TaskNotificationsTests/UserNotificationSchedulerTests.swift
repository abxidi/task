import Foundation
import XCTest
@testable import TaskNotifications

final class UserNotificationSchedulerTests: XCTestCase {
    func testScheduleUsesStableIdentifierAndCanCancel() async throws {
        let client = MockNotificationCenterClient()
        let scheduler = UserNotificationScheduler(client: client)
        let taskID = UUID()
        let fireAt = Date(timeIntervalSince1970: 5_000)
        try await scheduler.schedule(TaskReminder(taskID: taskID, title: "Review", fireAt: fireAt))
        XCTAssertEqual(client.added.first?.identifier, ReminderIdentifier.make(taskID: taskID))
        XCTAssertEqual(client.added.first?.title, "Review")
        XCTAssertEqual(client.added.first?.fireAt, fireAt)
        await scheduler.cancel(taskID: taskID)
        XCTAssertEqual(client.removed, [ReminderIdentifier.make(taskID: taskID)])
    }
}

private final class MockNotificationCenterClient: NotificationCenterClient, @unchecked Sendable {
    struct Added {
        let identifier: String
        let title: String
        let body: String
        let fireAt: Date
    }

    var added: [Added] = []
    var removed: [String] = []

    func requestAuthorization(options: UInt) async throws -> Bool { true }

    func add(identifier: String, title: String, body: String, fireAt: Date) async throws {
        added.append(.init(identifier: identifier, title: title, body: body, fireAt: fireAt))
    }

    func removePending(identifiers: [String]) async {
        removed.append(contentsOf: identifiers)
    }
}
