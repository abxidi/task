import AppKit
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
    @EnvironmentObject private var globalShortcutManager: GlobalShortcutManager
    @State private var keyCodeText = "40"
    @State private var keyDisplay = "K"
    @State private var modifiers: Set<GlobalShortcutModifier> = [.command]

    var body: some View {
        Form {
            Section("唤起快捷键") {
                Picker("方式", selection: shortcutModeBinding) {
                    Text("双击 Control").tag(GlobalShortcutMode.doubleControl)
                    Text("自定义组合键").tag(GlobalShortcutMode.custom)
                    Text("停用").tag(GlobalShortcutMode.disabled)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("唤起快捷键方式")
                .accessibilityValue(shortcutModeAccessibilityValue)

                if globalShortcutManager.configuration.mode == .doubleControl {
                    Text("0.4 秒内完成；仅显示并激活 Task 主窗口")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !globalShortcutManager.isInputMonitoringAuthorized {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                            Text("需要允许输入监控，才能识别连按两次 Control。")
                            Button("打开系统设置", action: openInputMonitoringSettings)
                                .accessibilityLabel("打开输入监控系统设置")
                        }
                        .font(.callout)
                    }
                }

                if globalShortcutManager.configuration.mode == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("键码", text: $keyCodeText)
                                .frame(width: 70)
                                .accessibilityLabel("自定义快捷键键码")
                            TextField("按键显示", text: $keyDisplay)
                                .frame(width: 80)
                                .accessibilityLabel("自定义快捷键按键")
                            Button("应用", action: applyCustomShortcut)
                                .accessibilityLabel("应用自定义唤起快捷键")
                        }
                        HStack(spacing: 12) {
                            modifierToggle(.command, label: "Command")
                            modifierToggle(.option, label: "Option")
                            modifierToggle(.control, label: "Control")
                            modifierToggle(.shift, label: "Shift")
                        }
                        Text(currentCustomShortcutText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("已录入组合键 \(currentCustomShortcutText)")
                    }
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                globalShortcutManager.hasCustomShortcutRegistrationError ? Color.red : .clear,
                                lineWidth: 1
                            )
                    }

                    if globalShortcutManager.hasCustomShortcutRegistrationError {
                        Text("该组合键不可用")
                            .foregroundStyle(.red)
                            .accessibilityLabel("自定义快捷键注册失败，该组合键不可用")
                    }
                }
            }
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
        .taskSubtleScrollIndicators()
        .onAppear {
            synchronizeCustomShortcutFields()
            globalShortcutManager.refreshInputMonitoringPermission()
        }
    }

    private var shortcutModeBinding: Binding<GlobalShortcutMode> {
        Binding(
            get: { globalShortcutManager.configuration.mode },
            set: { mode in
                switch mode {
                case .custom:
                    applyCustomShortcut()
                case .doubleControl, .disabled:
                    _ = globalShortcutManager.apply(.init(mode: mode))
                }
            }
        )
    }

    private var currentCustomShortcutText: String {
        guard let keyCode = UInt16(keyCodeText), !keyDisplay.isEmpty else {
            return "请输入键码和按键"
        }
        return GlobalShortcutKeyCombination(
            keyCode: keyCode,
            keyDisplay: keyDisplay.uppercased(),
            modifiers: modifiers
        ).displayText
    }

    private var shortcutModeAccessibilityValue: String {
        switch globalShortcutManager.configuration.mode {
        case .doubleControl:
            return globalShortcutManager.isInputMonitoringAuthorized ? "双击 Control，已生效" : "双击 Control，需要输入监控权限"
        case .custom:
            return globalShortcutManager.activeConfiguration?.mode == .custom ? "自定义组合键，已生效" : "自定义组合键，未生效"
        case .disabled:
            return "已停用"
        }
    }

    @ViewBuilder
    private func modifierToggle(_ modifier: GlobalShortcutModifier, label: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { modifiers.contains(modifier) },
            set: { isEnabled in
                if isEnabled {
                    modifiers.insert(modifier)
                } else {
                    modifiers.remove(modifier)
                }
            }
        ))
        .toggleStyle(.checkbox)
        .accessibilityLabel("自定义快捷键 \(label) 修饰键")
    }

    private func applyCustomShortcut() {
        guard let keyCode = UInt16(keyCodeText), !keyDisplay.isEmpty else { return }
        let shortcut = GlobalShortcutKeyCombination(
            keyCode: keyCode,
            keyDisplay: keyDisplay.uppercased(),
            modifiers: modifiers
        )
        _ = globalShortcutManager.apply(.init(mode: .custom, customShortcut: shortcut))
    }

    private func synchronizeCustomShortcutFields() {
        guard let shortcut = globalShortcutManager.configuration.customShortcut else { return }
        keyCodeText = String(shortcut.keyCode)
        keyDisplay = shortcut.keyDisplay
        modifiers = shortcut.modifiers
    }

    private func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
}
