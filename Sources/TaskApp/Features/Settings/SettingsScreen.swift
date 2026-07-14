import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                eyebrow: "本机设置",
                title: "设置"
            )
            .padding(.horizontal, 26)
            .padding(.top, 25)
            .padding(.bottom, 16)

            TabView {
                GeneralSettingsView()
                    .tabItem { Label("通用", systemImage: "slider.horizontal.3") }
                AISettingsView()
                    .tabItem { Label("AI", systemImage: "sparkles") }
                NotificationSettingsView()
                    .tabItem { Label("提醒", systemImage: "bell") }
                BackupSettingsView()
                    .tabItem { Label("备份", systemImage: "externaldrive") }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(TaskDesignTokens.canvas)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("dailyCapacityMinutes") private var capacityMinutes = 480

    var body: some View {
        Form {
            Section("每日可投入时间") {
                Stepper(value: $capacityMinutes, in: 60...24 * 60, step: 30) {
                    Text("\(capacityMinutes) 分钟")
                }
            }
            Section("关于") {
                Text("Task 是本机优先的任务管理应用。")
                Text("数据仅保存在这台 Mac。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
