import Foundation
import UserNotifications

public struct UserNotificationScheduler: ReminderScheduling {
    private let client: NotificationCenterClient

    public init(client: NotificationCenterClient = SystemNotificationCenterClient()) {
        self.client = client
    }

    public func requestAuthorization() async throws -> Bool {
        try await client.requestAuthorization(options: UNAuthorizationOptions.alert.rawValue | UNAuthorizationOptions.sound.rawValue)
    }

    public func schedule(_ reminder: TaskReminder) async throws {
        let identifier = ReminderIdentifier.make(taskID: reminder.taskID)
        try await client.add(
            identifier: identifier,
            title: reminder.title,
            body: "任务提醒",
            fireAt: reminder.fireAt
        )
    }

    public func cancel(taskID: UUID) async {
        await client.removePending(identifiers: [ReminderIdentifier.make(taskID: taskID)])
    }
}

public struct SystemNotificationCenterClient: NotificationCenterClient {
    public init() {}

    public func requestAuthorization(options: UInt) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions(rawValue: options))
    }

    public func add(identifier: String, title: String, body: String, fireAt: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    public func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
