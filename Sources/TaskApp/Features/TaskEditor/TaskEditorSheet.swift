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
    @State private var descriptionFocused = false
    @State private var noteHeight = TaskEditorNoteLayout.minimumHeight
    @State private var reminderWarning: String?
    @State private var isPriorityPickerPresented = false
    @State private var autoSaveTask: Swift.Task<Void, Never>?
    @StateObject private var markdownSession: MarkdownDraftSession
    @State private var isMarkdownPresented = false
    private let onClose: (() -> Void)?
    private let outsideDismissToken: UUID?
    private let onSubtaskCountChange: (Int) -> Void
    private let onNoteHeightChange: (CGFloat) -> Void

    init(
        mode: TaskEditorMode,
        onClose: (() -> Void)? = nil,
        outsideDismissToken: UUID? = nil,
        onSubtaskCountChange: @escaping (Int) -> Void = { _ in },
        onNoteHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.onClose = onClose
        self.outsideDismissToken = outsideDismissToken
        self.onSubtaskCountChange = onSubtaskCountChange
        self.onNoteHeightChange = onNoteHeightChange
        let editorModel: TaskEditorModel
        switch mode {
        case .create:
            editorModel = TaskEditorModel(draft: TaskDraft(title: ""))
        case .createInColumn(let columnID):
            editorModel = TaskEditorModel(draft: TaskDraft(title: "", boardColumnID: columnID))
        case .edit(let item):
            editorModel = TaskEditorModel(draft: TaskEditorModel.draft(from: item), existing: item)
        }
        _model = StateObject(wrappedValue: editorModel)
        _markdownSession = StateObject(wrappedValue: MarkdownDraftSession(details: editorModel.draft.details))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    closeEditor()
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            priorityEntry

                            ZStack(alignment: .leading) {
                                if TaskEditorPlaceholder.isVisible(text: model.draft.title, isFocused: titleFocused) {
                                    Text("任务标题")
                                        .font(TaskDesignTokens.sheetTitleFont)
                                        .foregroundStyle(TaskDesignTokens.quiet.opacity(TaskEditorPlaceholder.opacity))
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: $model.draft.title)
                                    .textFieldStyle(.plain)
                                    .font(TaskDesignTokens.sheetTitleFont)
                                    .foregroundStyle(TaskDesignTokens.ink)
                                    .focused($titleFocused)
                                    .frame(minHeight: TaskEditorTitleMetrics.minimumFieldHeight)
                            }
                        }
                        Rectangle()
                            .fill(TaskDesignTokens.line)
                            .frame(height: 1)
                    }
                    .frame(width: TaskEditorLayout.titleContentWidth, alignment: .leading)

                    ZStack(alignment: .topLeading) {
                        if TaskEditorPlaceholder.isVisible(text: model.draft.details, isFocused: descriptionFocused) {
                                Text("添加备注...")
                                    .font(.system(size: 15))
                                    .foregroundStyle(TaskDesignTokens.quiet.opacity(TaskEditorPlaceholder.opacity))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 7)
                                    .allowsHitTesting(false)
                            }
                        AdaptiveNoteTextEditor(
                            text: $model.draft.details,
                            isFocused: $descriptionFocused
                        ) { measuredHeight in
                            guard noteHeight != measuredHeight else { return }
                            noteHeight = measuredHeight
                            onNoteHeightChange(measuredHeight)
                        }
                    }
                    .frame(height: noteHeight)
                    .padding(.top, 14)

                    subtaskEditor
                        .padding(.top, 20)

                    editorMetadata
                        .padding(.top, 28)
                }
            }
            .taskSubtleScrollIndicators()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 64)
            .padding(.bottom, 24)
            .background(TaskDesignTokens.panel)

        }
        .frame(minWidth: 820, idealWidth: 980)
        .background(TaskDesignTokens.panel)
        .onAppear {
            titleFocused = true
            onSubtaskCountChange(model.draft.subtasks.count)
        }
        .onChange(of: model.draft.subtasks.count) { _, count in
            onSubtaskCountChange(count)
        }
        .onChange(of: model.draft) { _, _ in
            scheduleAutoSave()
        }
        .onChange(of: outsideDismissToken) { _, token in
            if token != nil { closeEditor() }
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
        .onExitCommand {
            closeEditor()
        }
        .alert("自动保存失败", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { titleFocused = true }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay {
            if isMarkdownPresented {
                MarkdownTaskEditor(
                    session: markdownSession,
                    task: { model.existing },
                    onSave: { details in
                        model.acceptSavedDetails(details)
                        isMarkdownPresented = false
                    },
                    onCancel: { isMarkdownPresented = false }
                )
            }
        }
    }

    private var subtaskEditor: some View {
        SubtaskEditor(
            items: $model.draft.subtasks,
            completion: $model.draft.subtaskCompletion,
            ids: $model.draft.subtaskIDs,
            onToggle: { model.draft.toggleSubtaskCompletion(at: $0) },
            onMove: moveSubtasks,
            onDelete: removeSubtask,
            onAdd: { model.draft.addSubtask($0) },
            attachments: attachments(for:),
            onPasteImage: { subtaskID, image in
                try addAttachment(image, to: subtaskID)
            },
            onDeleteAttachment: removeAttachment
        )
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
            TaskTagEditor(tagNames: $model.draft.tagNames)

            TaskDateEditorRow(
                startAt: $model.draft.startAt,
                dueAt: $model.draft.dueAt,
                reminderAt: $model.draft.reminderAt
            )
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Swift.Task { @MainActor in
            try? await Swift.Task.sleep(for: .milliseconds(250))
            guard !Swift.Task.isCancelled else { return }
            _ = persistDraft()
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard !model.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        do {
            let repository = TaskRepository(context: modelContext)
            guard let saved = try model.autoSave(using: repository) else { return true }
            model.errorMessage = nil
            Swift.Task { await syncReminder(for: saved) }
            return true
        } catch {
            model.errorMessage = error.localizedDescription
            return false
        }
    }

    private func moveSubtasks(from source: IndexSet, to destination: Int) {
        model.draft.subtasks.move(fromOffsets: source, toOffset: destination)
        model.draft.subtaskCompletion.move(fromOffsets: source, toOffset: destination)
        model.draft.subtaskIDs.move(fromOffsets: source, toOffset: destination)
        model.draft.normalizeSubtaskOrdering()
    }

    private func removeSubtask(at index: Int) {
        guard model.draft.subtasks.indices.contains(index) else { return }
        model.draft.subtasks.remove(at: index)
        model.draft.subtaskCompletion.remove(at: index)
        model.draft.subtaskIDs.remove(at: index)
    }

    private func attachments(for subtaskID: UUID) -> [SubtaskAttachment] {
        guard let subtask = model.existing?.subtasks.first(where: { $0.id == subtaskID }) else {
            return []
        }
        return subtask.attachments.sorted { $0.createdAt < $1.createdAt }
    }

    private func addAttachment(_ image: NSImage, to subtaskID: UUID) throws {
        guard persistDraft(), let subtask = model.existing?.subtasks.first(where: { $0.id == subtaskID }) else {
            return
        }
        let processed = try SubtaskImageProcessor.process(image)
        try SubtaskAttachmentRepository(context: modelContext).add(
            imageData: processed.imageData,
            thumbnailData: processed.thumbnailData,
            to: subtask
        )
    }

    private func removeAttachment(_ attachment: SubtaskAttachment) throws {
        try SubtaskAttachmentRepository(context: modelContext).remove(attachment)
    }

    private func openMarkdown() {
        guard persistDraft(), model.existing != nil else { return }
        markdownSession.details = model.draft.details
        isMarkdownPresented = true
    }

    private func closeEditor() {
        autoSaveTask?.cancel()
        autoSaveTask = nil
        guard persistDraft() else { return }

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

enum TaskEditorPlaceholder {
    static let opacity: Double = 0.55

    static func isVisible(text: String, isFocused: Bool) -> Bool {
        text.isEmpty && !isFocused
    }
}

enum TaskEditorLayout {
    static let usesInlineMetadata = true
    static let showsTaskSettingsEntry = false
    static let usesAutomaticSave = true
    static let showsSaveButton = false
    static let showsCancelButton = false
    static let supportsEscapeToClose = true
    static let titleContentWidth: CGFloat = 460
    static let emptySubtaskHeight: CGFloat = 40
    static let usesAdaptiveNoteHeight = true
    static let expandsNoteOnlyForFocus = false
    static let noteMinimumHeight = TaskEditorNoteLayout.minimumHeight
    static let noteMaximumHeight = TaskEditorNoteLayout.maximumHeight
}

enum TaskEditorPriorityLabel {
    static func title(for coordinate: PriorityCoordinate) -> String {
        if coordinate.importance >= 2 { return "高优" }
        if coordinate.importance <= -2 { return "低优" }
        return "正常"
    }
}
