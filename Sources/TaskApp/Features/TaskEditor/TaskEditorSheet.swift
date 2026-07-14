import SwiftData
import SwiftUI
import TaskDomain
import TaskNotifications
import TaskPersistence

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model: TaskEditorModel
    @FocusState private var titleFocused: Bool
    @State private var reminderWarning: String?

    init(mode: TaskEditorMode) {
        switch mode {
        case .create:
            _model = StateObject(wrappedValue: TaskEditorModel(draft: TaskDraft(title: "")))
        case .edit(let item):
            _model = StateObject(wrappedValue: TaskEditorModel(draft: TaskEditorModel.draft(from: item), existing: item))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(model.existing == nil ? "新建任务" : "编辑任务")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.ink)
                Text("⌘N")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    )
                Spacer()
                Button {
                    model.isSettingsPresented.toggle()
                } label: {
                    Label("任务设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 31)
                        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.lineStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .help("打开任务设置")

                Button {
                    attemptDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.quiet)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            .background(TaskDesignTokens.panel)
            .overlay(alignment: .bottom) {
                Rectangle().fill(TaskDesignTokens.line).frame(height: 1)
            }

            // Body
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("任务标题", text: $model.draft.title)
                            .textFieldStyle(.plain)
                            .font(TaskDesignTokens.sheetTitleFont)
                            .foregroundStyle(TaskDesignTokens.ink)
                            .focused($titleFocused)
                            .padding(.bottom, 14)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(TaskDesignTokens.line).frame(height: 1)
                            }

                        HStack {
                            Text("任务描述")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                            Text("支持轻量 Markdown")
                                .font(.system(size: 8))
                                .foregroundStyle(TaskDesignTokens.quiet)
                        }
                        .padding(.top, 22)

                        TextEditor(text: $model.draft.details)
                            .font(.system(size: 12))
                            .foregroundStyle(TaskDesignTokens.muted)
                            .scrollContentBackground(.hidden)
                            .padding(14)
                            .frame(minHeight: 170)
                            .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
                            .padding(.top, 9)

                        SubtaskEditor(items: $model.draft.subtasks)
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 34)
                    .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity)
                .background(TaskDesignTokens.panel)

                if model.isSettingsPresented {
                    TaskSettingsInspector(draft: $model.draft)
                        .frame(width: 340)
                        .background(TaskDesignTokens.settingsPanel)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(TaskDesignTokens.line).frame(width: 1)
                        }
                }
            }

            // Footer
            HStack {
                Text("⌘↩ 保存　Esc 取消")
                    .font(.system(size: 8))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Spacer()
                TaskChromeButton(title: "取消", action: attemptDismiss)
                TaskChromeButton(title: "保存任务", style: .primary, action: save)
                    .disabled(!model.canSave)
                    .opacity(model.canSave ? 1 : 0.5)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(TaskDesignTokens.sheetFoot)
            .overlay(alignment: .top) {
                Rectangle().fill(TaskDesignTokens.line).frame(height: 1)
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 560)
        .background(TaskDesignTokens.panel)
        .onAppear { titleFocused = true }
        .alert("无法保存", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { titleFocused = true }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("放弃未保存的修改？", isPresented: $model.showDiscardConfirmation) {
            Button("放弃", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        }
    }

    private func save() {
        do {
            let repository = TaskRepository(context: modelContext)
            let saved: TaskItem
            if let existing = model.existing {
                try repository.updateTask(existing, with: model.draft)
                saved = existing
            } else {
                saved = try repository.saveNewTask(model.draft)
            }
            Task { await syncReminder(for: saved) }
            dismiss()
        } catch TaskDraftError.emptyTitle {
            model.errorMessage = "请输入任务标题"
            titleFocused = true
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func attemptDismiss() {
        if model.isDirty {
            model.showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func syncReminder(for item: TaskItem) async {
        let scheduler = UserNotificationScheduler()
        if item.isCompleted || item.reminderAt == nil {
            await scheduler.cancel(taskID: item.id)
            return
        }
        guard let fireAt = item.reminderAt else { return }
        do {
            _ = try await scheduler.requestAuthorization()
            try await scheduler.schedule(TaskReminder(taskID: item.id, title: item.title, fireAt: fireAt))
        } catch {
            reminderWarning = "任务已保存，但提醒未成功注册"
        }
    }
}
