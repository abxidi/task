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
    @FocusState private var descriptionFocused: Bool
    @State private var reminderWarning: String?
    @State private var isPriorityPickerPresented = false
    @State private var isEditingTags = false
    private let onClose: (() -> Void)?
    private let outsideDismissToken: UUID?

    init(
        mode: TaskEditorMode,
        onClose: (() -> Void)? = nil,
        outsideDismissToken: UUID? = nil
    ) {
        self.onClose = onClose
        self.outsideDismissToken = outsideDismissToken
        switch mode {
        case .create:
            _model = StateObject(wrappedValue: TaskEditorModel(draft: TaskDraft(title: "")))
        case .createInColumn(let columnID):
            _model = StateObject(wrappedValue: TaskEditorModel(draft: TaskDraft(title: "", boardColumnID: columnID)))
        case .edit(let item):
            _model = StateObject(wrappedValue: TaskEditorModel(draft: TaskEditorModel.draft(from: item), existing: item))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
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
            .padding(.horizontal, 24)
            .frame(height: 40)
            .background(TaskDesignTokens.panel)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            priorityEntry

                            TextField("任务标题", text: $model.draft.title)
                                .textFieldStyle(.plain)
                                .font(TaskDesignTokens.sheetTitleFont)
                                .foregroundStyle(TaskDesignTokens.ink)
                                .focused($titleFocused)
                                .frame(minHeight: TaskEditorTitleMetrics.minimumFieldHeight)
                        }
                        Rectangle()
                            .fill(TaskDesignTokens.line)
                            .frame(height: 1)
                    }
                    .frame(width: TaskEditorLayout.titleContentWidth, alignment: .leading)

                    ZStack(alignment: .topLeading) {
                        if model.draft.details.isEmpty {
                            Text("添加备注...")
                                .font(.system(size: 15))
                                .foregroundStyle(TaskDesignTokens.quiet)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 13)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $model.draft.details)
                            .font(.system(size: 15))
                            .foregroundStyle(TaskDesignTokens.muted)
                            .scrollContentBackground(.hidden)
                            .focused($descriptionFocused)
                            .padding(.vertical, 8)
                    }
                    .frame(height: isDescriptionExpanded ? 142 : 48)
                    .padding(.top, 14)

                    SubtaskEditor(
                        items: $model.draft.subtasks,
                        completion: $model.draft.subtaskCompletion
                    )
                    .padding(.top, 20)

                    editorMetadata
                        .padding(.top, 28)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 64)
            .padding(.bottom, 24)
            .background(TaskDesignTokens.panel)

            // Footer
            HStack {
                Text("⌘↩ 保存　Esc 取消")
                    .font(.system(size: 8))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Spacer()
                Button {
                    model.draft.isCompleted.toggle()
                } label: {
                    Image(systemName: model.draft.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(model.draft.isCompleted ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(model.draft.isCompleted ? "标记为未完成" : "标记为已完成")
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
        .frame(minWidth: 820, idealWidth: 980, minHeight: 620)
        .background(TaskDesignTokens.panel)
        .onAppear { titleFocused = true }
        .onChange(of: outsideDismissToken) { _, token in
            if token != nil { attemptDismiss() }
        }
        .alert("无法保存", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { titleFocused = true }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("放弃未保存的修改？", isPresented: $model.showDiscardConfirmation) {
            Button("放弃", role: .destructive) { finishDismiss() }
            Button("继续编辑", role: .cancel) {}
        }
    }

    private var isDescriptionExpanded: Bool {
        descriptionFocused || !model.draft.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var priorityEntry: some View {
        Button {
            isPriorityPickerPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                PriorityMarkerView(coordinate: model.draft.coordinate, title: "优先级", isSelected: false, isCompact: true)
                Text(TaskEditorPriorityLabel.title(for: model.draft.coordinate))
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(TaskDesignTokens.muted)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.lineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .help("设置任务优先级")
        .popover(isPresented: $isPriorityPickerPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("任务优先级")
                    .font(.system(size: 12, weight: .bold))
                Text("颜色表示紧急度，数字表示重要度")
                    .font(.system(size: 9))
                    .foregroundStyle(TaskDesignTokens.quiet)
                PriorityCoordinateEditor(coordinate: $model.draft.coordinate)
                    .frame(width: 320, height: 320)
            }
            .padding(16)
        }
    }

    private var editorMetadata: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("任务标签")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.muted)
                if model.draft.tagNames.isEmpty && !isEditingTags {
                    Button {
                        isEditingTags = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(TaskDesignTokens.quiet)
                    }
                    .buttonStyle(.plain)
                    .help("添加标签")
                } else {
                    TextField("添加标签，用逗号分隔", text: tagText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(width: 260, height: 30)
                        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.line, lineWidth: 1))
                        .onSubmit { isEditingTags = false }
                }
            }

            HStack(spacing: 12) {
                Text("任务日期")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.muted)
                Toggle("", isOn: hasDueDate)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                if model.draft.dueAt != nil {
                    DatePicker("", selection: dueDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                } else {
                    Text("未设置")
                        .font(.system(size: 12))
                        .foregroundStyle(TaskDesignTokens.quiet)
                }
                Spacer()
            }
        }
    }

    private var tagText: Binding<String> {
        Binding(
            get: { model.draft.tagNames.joined(separator: ", ") },
            set: {
                model.draft.tagNames = $0.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { model.draft.dueAt != nil },
            set: { model.draft.dueAt = $0 ? (model.draft.dueAt ?? .now) : nil }
        )
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: { model.draft.dueAt ?? .now },
            set: { model.draft.dueAt = $0 }
        )
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
            finishDismiss()
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
            finishDismiss()
        }
    }

    private func finishDismiss() {
        if let onClose {
            onClose()
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

enum TaskEditorTitleMetrics {
    static let minimumFieldHeight: CGFloat = 44
}

enum TaskEditorLayout {
    static let usesInlineMetadata = true
    static let showsTaskSettingsEntry = false
    static let titleContentWidth: CGFloat = 460
    static let emptySubtaskHeight: CGFloat = 68
}

enum TaskEditorPriorityLabel {
    static func title(for coordinate: PriorityCoordinate) -> String {
        if coordinate.importance >= 2 { return "高优" }
        if coordinate.importance <= -2 { return "低优" }
        return "正常"
    }
}
