import AppKit
import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

enum FocusStateColorToken: String, Hashable {
    case green
    case yellow
    case red

    var color: Color {
        switch self {
        case .green: TaskDesignTokens.success
        case .yellow: TaskDesignTokens.warning
        case .red: TaskDesignTokens.danger
        }
    }
}

enum FocusStatePresentation {
    static func title(for state: TaskFocusState) -> String {
        switch state {
        case .focused: "专注"
        case .waiting: "等待"
        case .blocked: "阻塞"
        }
    }

    static func selectionColorToken(for state: TaskFocusState) -> FocusStateColorToken {
        switch state {
        case .focused: .green
        case .waiting: .yellow
        case .blocked: .red
        }
    }

    static func selectionColor(for state: TaskFocusState) -> Color {
        selectionColorToken(for: state).color
    }

    static func usesDarkSelectionText(for state: TaskFocusState) -> Bool {
        state == .waiting
    }
}

struct FocusSubtaskItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

enum FocusSubtaskCompletionSource {
    case checkbox
    case title
}

enum FocusPoolPresentation {
    static let pageTitleFontSize: CGFloat = 26
    static let actionFontSize: CGFloat = 11
    static let taskTitleFontSize: CGFloat = 11
    static let usesTwoColumnCard = true
    static let cardColumnSpacing: CGFloat = 20
    static let subtaskColumnMinWidth: CGFloat = 280
    static let statusControlWidth: CGFloat = 270
    static let statusSegmentWidth: CGFloat = 90
    static let statusControlFontSize: CGFloat = 11
    static let noteUsesPlainField = true
    static let noteUsesMultilineEditor = true
    static let statusControlUsesLeadingAlignment = true
    static let statusControlUsesTrailingSpacer = false
    static let statusControlUsesNativePicker = false
    static let subtasksUseCheckboxes = true
    static let subtasksSupportReordering = true
    static let showsStatusSymbol = false

    static func canAddTask(isCompleted: Bool, hasFocusEntry: Bool) -> Bool {
        !isCompleted && !hasFocusEntry
    }

    static func incompleteSubtasks(from subtasks: [FocusSubtaskItem]) -> [FocusSubtaskItem] {
        SubtaskOrder.incompleteFirst(subtasks, isCompleted: \.isCompleted)
            .filter { !$0.isCompleted }
    }

    static func allowsSubtaskCompletion(from source: FocusSubtaskCompletionSource) -> Bool {
        source == .checkbox
    }

    static func sortsByTaskPriority(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        TaskSort.priority(
            TaskSortValue(
                id: lhs.id.uuidString,
                urgency: lhs.urgency,
                importance: lhs.importance,
                dueAt: lhs.dueAt,
                createdAt: lhs.createdAt
            ),
            TaskSortValue(
                id: rhs.id.uuidString,
                urgency: rhs.urgency,
                importance: rhs.importance,
                dueAt: rhs.dueAt,
                createdAt: rhs.createdAt
            )
        )
    }
}

private struct FocusStateSegmentedControl: View {
    @Binding var selection: TaskFocusState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskFocusState.allCases, id: \.self) { option in
                segment(for: option)
            }
        }
        .frame(width: FocusPoolPresentation.statusControlWidth, alignment: .leading)
        .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius))
    }

    private func segment(for option: TaskFocusState) -> some View {
        let title = FocusStatePresentation.title(for: option)
        let isSelected = selection == option

        return Button {
            selection = option
        } label: {
            segmentLabel(title: title, state: option, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("当前状态：\(title)")
        .accessibilityValue(isSelected ? "已选中" : "未选中")
    }

    private func segmentLabel(title: String, state: TaskFocusState, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: FocusPoolPresentation.statusControlFontSize, weight: .semibold))
            .foregroundStyle(
                isSelected && !FocusStatePresentation.usesDarkSelectionText(for: state)
                    ? Color.white
                    : TaskDesignTokens.ink
            )
            .frame(width: FocusPoolPresentation.statusSegmentWidth, height: 30)
            .background(isSelected ? FocusStatePresentation.selectionColor(for: state) : Color.clear)
            .contentShape(Rectangle())
    }
}

struct FocusPoolScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \FocusEntry.updatedAt, order: .reverse) private var entries: [FocusEntry]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 26)
                .padding(.top, 25)
                .padding(.bottom, 16)

            if entries.isEmpty {
                ContentUnavailableView(
                    "暂无正在做事项",
                    systemImage: "scope"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(prioritySortedEntries, id: \.id) { entry in
                            FocusEntryRow(
                                entry: entry,
                                onRemove: { remove(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
                }
                .taskSubtleScrollIndicators()
            }
        }
        .background(TaskDesignTokens.canvas)
        .onAppear(perform: migrateLegacyStates)
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("工作台")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Text("正在做")
                    .font(TaskDesignTokens.pageTitleFont)
                    .foregroundStyle(TaskDesignTokens.ink)
            }

            Spacer()

            Menu {
                if availableTasks.isEmpty {
                    Text("没有可加入的任务")
                } else {
                    ForEach(availableTasks, id: \.id) { task in
                        Button(task.title) {
                            add(task)
                        }
                    }
                }
            } label: {
                Label("加入任务", systemImage: "plus")
                    .font(.system(size: FocusPoolPresentation.actionFontSize, weight: .bold))
                    .padding(.horizontal, 11)
                    .frame(minHeight: 30)
                    .foregroundStyle(TaskDesignTokens.acid)
                    .background(TaskDesignTokens.ink, in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius))
            }
            .menuStyle(.borderlessButton)
            .disabled(availableTasks.isEmpty)
            .help("将已有任务加入正在做")
        }
    }

    private var availableTasks: [TaskItem] {
        tasks.filter {
            FocusPoolPresentation.canAddTask(
                isCompleted: $0.isCompleted,
                hasFocusEntry: $0.focusEntry != nil
            )
        }
    }

    private var prioritySortedEntries: [FocusEntry] {
        entries.sorted { lhs, rhs in
            switch (lhs.task, rhs.task) {
            case let (lhsTask?, rhsTask?):
                FocusPoolPresentation.sortsByTaskPriority(lhsTask, rhsTask)
            case (.some, nil):
                true
            case (nil, .some):
                false
            case (nil, nil):
                lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    private func add(_ task: TaskItem) {
        do {
            _ = try FocusRepository(context: modelContext).upsert(task: task, state: .focused, note: "")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ entry: FocusEntry) {
        do {
            try FocusRepository(context: modelContext).remove(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func migrateLegacyStates() {
        do {
            _ = try FocusRepository(context: modelContext).migrateLegacyStates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FocusEntryRow: View {
    @Environment(\.modelContext) private var modelContext
    let entry: FocusEntry
    let onRemove: () -> Void
    @State private var state: TaskFocusState
    @State private var note: String
    @State private var newSubtaskTitle = ""
    @State private var errorMessage: String?

    init(entry: FocusEntry, onRemove: @escaping () -> Void) {
        self.entry = entry
        self.onRemove = onRemove
        _state = State(initialValue: entry.state)
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        HStack(alignment: .top, spacing: FocusPoolPresentation.cardColumnSpacing) {
            leftColumn

            Divider()
                .frame(minHeight: 132)

            incompleteSubtasksColumn
        }
        .padding(12)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
        .alert("无法保存正在做内容", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var leftColumn: some View {
        HStack(alignment: .top, spacing: 12) {
            PriorityMarkerView(
                coordinate: .init(uncheckedUrgency: entry.task?.urgency ?? 0, importance: entry.task?.importance ?? 0),
                title: entry.task?.title ?? "任务",
                isSelected: false,
                isCompact: true
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(entry.task?.title ?? "已删除任务")
                        .font(.system(size: FocusPoolPresentation.taskTitleFontSize, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.ink)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .help("移出正在做")
                    .accessibilityLabel("移出正在做")
                }

                FocusStateSegmentedControl(selection: $state)
                    .onChange(of: state) { _, _ in
                        persist()
                    }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $note)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .taskSubtleScrollIndicators()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 78, maxHeight: 140, alignment: .topLeading)
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                            .stroke(TaskDesignTokens.line, lineWidth: 1)
                    )
                    .onChange(of: note) { _, _ in
                        persist()
                    }
                    .accessibilityLabel("正在做备注")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var incompleteSubtasksColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("未完成子任务")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Text("\(incompleteSubtasks.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Spacer(minLength: 0)
            }

            if incompleteSubtasks.isEmpty {
                Text("暂无未完成子任务")
                    .font(.system(size: 11))
                    .foregroundStyle(TaskDesignTokens.quiet)
            } else {
                reorderDropZone(before: incompleteSubtasks[0].id)
                ForEach(incompleteSubtasks) { subtask in
                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            completeSubtask(subtask.id, from: .checkbox)
                        } label: {
                            Image(systemName: "square")
                                .font(.system(size: 13))
                                .foregroundStyle(TaskDesignTokens.quiet)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24, height: 24, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .help("标记子任务为已完成")
                        .accessibilityLabel("标记子任务为已完成：\(subtask.title)")

                        FocusSubtaskTitleEditor(
                            subtask: subtask,
                            onSave: { id, title in
                                try updateSubtaskTitle(id, title: title)
                            },
                            onFailure: { errorMessage = $0.localizedDescription }
                        )

                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TaskDesignTokens.quiet)
                            .help("拖动排序")
                            .accessibilityLabel("拖动排序")
                    }
                    .onDrag {
                        NSItemProvider(object: subtask.id.uuidString as NSString)
                    }
                    .dropDestination(for: String.self) { values, _ in
                        moveSubtask(from: values, before: subtask.id)
                    }
                }
                reorderDropZone(after: incompleteSubtasks[incompleteSubtasks.count - 1].id)
            }

            if entry.task != nil {
                addSubtaskInput
            }
        }
        .frame(minWidth: FocusPoolPresentation.subtaskColumnMinWidth, maxWidth: .infinity, alignment: .leading)
    }

    private var addSubtaskInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(width: 18, height: 18)

            TextField("添加子任务", text: $newSubtaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(TaskDesignTokens.muted)
                .onSubmit(addSubtask)
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    addSubtask()
                    return .handled
                }
                .accessibilityLabel("添加子任务")
                .accessibilityHint("按 Return 创建子任务")
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                .stroke(
                    TaskDesignTokens.line,
                    style: StrokeStyle(lineWidth: 1, dash: [4])
                )
        )
    }

    private var incompleteSubtasks: [FocusSubtaskItem] {
        FocusPoolPresentation.incompleteSubtasks(
            from: entry.task?.subtasks.sorted { $0.order < $1.order }.map {
                FocusSubtaskItem(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
            } ?? []
        )
    }

    private func completeSubtask(_ id: UUID, from source: FocusSubtaskCompletionSource) {
        guard FocusPoolPresentation.allowsSubtaskCompletion(from: source),
              let subtask = entry.task?.subtasks.first(where: { $0.id == id }) else { return }
        do {
            try TaskRepository(context: modelContext).setSubtaskCompleted(subtask, isCompleted: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSubtaskTitle(_ id: UUID, title: String) throws {
        guard let subtask = entry.task?.subtasks.first(where: { $0.id == id }) else { return }
        try TaskRepository(context: modelContext).updateSubtaskTitle(subtask, title: title)
    }

    private func addSubtask() {
        guard let task = entry.task else { return }
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        do {
            _ = try TaskRepository(context: modelContext).addSubtask(to: task, title: title)
            newSubtaskTitle = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reorderDropZone(before id: UUID) -> some View {
        Color.clear
            .frame(height: 6)
            .dropDestination(for: String.self) { values, _ in
                moveSubtask(from: values, before: id)
            }
    }

    private func reorderDropZone(after id: UUID) -> some View {
        Color.clear
            .frame(height: 6)
            .dropDestination(for: String.self) { values, _ in
                moveSubtask(from: values, after: id)
            }
    }

    private func moveSubtask(from values: [String], before id: UUID) -> Bool {
        guard let sourceID = values.first.flatMap(UUID.init(uuidString:)),
              let source = entry.task?.subtasks.first(where: { $0.id == sourceID }),
              let destination = entry.task?.subtasks.first(where: { $0.id == id }),
              source.id != destination.id else {
            return false
        }

        do {
            try TaskRepository(context: modelContext).moveSubtask(source, before: destination)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func moveSubtask(from values: [String], after id: UUID) -> Bool {
        guard let sourceID = values.first.flatMap(UUID.init(uuidString:)),
              let source = entry.task?.subtasks.first(where: { $0.id == sourceID }),
              let destination = entry.task?.subtasks.first(where: { $0.id == id }),
              source.id != destination.id else {
            return false
        }

        do {
            try TaskRepository(context: modelContext).moveSubtask(source, after: destination)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func persist() {
        guard let task = entry.task else { return }
        do {
            _ = try FocusRepository(context: modelContext).upsert(task: task, state: state, note: note)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FocusSubtaskTitleEditor: View {
    let subtask: FocusSubtaskItem
    let onSave: (UUID, String) throws -> Void
    let onFailure: (Error) -> Void

    @State private var title: String
    @State private var persistedTitle: String
    @FocusState private var isFocused: Bool

    init(
        subtask: FocusSubtaskItem,
        onSave: @escaping (UUID, String) throws -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.subtask = subtask
        self.onSave = onSave
        self.onFailure = onFailure
        _title = State(initialValue: subtask.title)
        _persistedTitle = State(initialValue: subtask.title)
    }

    var body: some View {
        TextField("子任务", text: $title, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(TaskDesignTokens.muted)
            .lineLimit(1...2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { _, hasFocus in
                if !hasFocus {
                    commit()
                }
            }
            .onDisappear(perform: commit)
            .accessibilityLabel("编辑子任务：\(subtask.title)")
            .accessibilityHint("按 Return 或移开焦点保存")
    }

    private func commit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle != persistedTitle else {
            title = persistedTitle
            return
        }

        do {
            try onSave(subtask.id, trimmedTitle)
            title = trimmedTitle
            persistedTitle = trimmedTitle
        } catch {
            title = persistedTitle
            onFailure(error)
        }
    }
}
