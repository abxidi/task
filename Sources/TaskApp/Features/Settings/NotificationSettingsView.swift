import SwiftUI
import TaskNotifications

struct NotificationSettingsView: View {
    @State private var status = "尚未请求通知权限"
    private let scheduler = UserNotificationScheduler()

    var body: some View {
        Form {
            Section("本地提醒") {
                Text("仅在你为任务设置提醒时才会请求系统通知权限。")
                    .foregroundStyle(.secondary)
                Button("请求通知权限") {
                    Task {
                        do {
                            let granted = try await scheduler.requestAuthorization()
                            status = granted ? "已授权" : "已拒绝（任务仍可保存提醒时间）"
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                Text(status)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
