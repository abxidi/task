import AppKit
import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

enum FocusStateColorToken: String, Hashable {
    case green
    case yellow
    case red

    var signalLightHex: UInt32 {
        switch self {
        case .green: 0x35D6B5
        case .yellow: 0xF2C440
        case .red: 0xEF5058
        }
    }

    var color: Color {
        Color(hex: signalLightHex)
    }
}

enum FocusStateMarkerStyle: Equatable {
    case filled
    case hollow
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

struct FocusCardColumnWidths: Equatable {
    let left: CGFloat
    let right: CGFloat
}

enum FocusSubtaskCompletionSource {
    case checkbox
    case title
}

enum FocusPoolPresentation {
    static let pageTitle = AppRoute.focusPool.sidebarTitle
    static let pageTitleFontSize: CGFloat = 26
    static let actionFontSize: CGFloat = 11
    static let taskTitleFontSize: CGFloat = 11
    static let usesTwoColumnCard = true
    static let cardColumnSpacing: CGFloat = 20
    static let dividerWidth: CGFloat = 1
    static let leftColumnRatio: CGFloat = 0.46
    static let rightColumnRatio: CGFloat = 0.54
    static let leftColumnMinWidth: CGFloat = 276
    static let subtaskColumnMinWidth: CGFloat = 280
    static let minimumTwoColumnWidth = max(
        leftColumnMinWidth / leftColumnRatio,
        subtaskColumnMinWidth / rightColumnRatio
    ) + cardColumnSpacing * 2 + dividerWidth
    static let subtaskTitleFontSize: CGFloat = 12
    static let statusControlWidth: CGFloat = 240
    static let statusControlHeight: CGFloat = 32
    static let statusSegmentWidth: CGFloat = 78
    static let statusControlFontSize: CGFloat = 11
    static let statusSegmentHeight: CGFloat = 28
    static let selectedStatusMarkerSize: CGFloat = 11
    static let unselectedStatusMarkerSize: CGFloat = 11
    static let selectedStatusMarkerUsesDotMatrix = true
    static let selectedStatusMarkerDotCount = 9
    static let statusControlUsesSegmentedRail = true
    static let statusControlPlacesTitleAfterMarker = true
    static let statusControlUsesUniformMarkerSize = true
    static let statusControlUsesNeutralSurface = true
    static let statusControlSeparatesMarkerAndTitle = true
    static let statusControlUsesFilledStateBackground = false
    static let noteUsesPlainField = true
    static let noteUsesMultilineEditor = true
    static let statusControlUsesLeadingAlignment = true
    static let statusControlUsesTrailingSpacer = false
    static let statusControlUsesNativePicker = false
    static let subtasksUseCheckboxes = true
    static let subtasksSupportReordering = true
    static let subtasksShowInsertionIndicator = true
    static let subtaskTitlesUseMultilineField = true
    static let subtaskTitleMaximumLineCount: Int? = nil
    static let showsStatusSymbol = false

    static func markerStyle(isSelected: Bool) -> FocusStateMarkerStyle {
        isSelected ? .filled : .hollow
    }

    static func columnWidths(for availableWidth: CGFloat) -> FocusCardColumnWidths? {
        guard usesTwoColumnLayout(for: availableWidth) else { return nil }
        let columnsWidth = availableWidth - cardColumnSpacing * 2 - dividerWidth
        return FocusCardColumnWidths(
            left: columnsWidth * leftColumnRatio,
            right: columnsWidth * rightColumnRatio
        )
    }

    static func usesTwoColumnLayout(for availableWidth: CGFloat) -> Bool {
        availableWidth.isFinite && availableWidth >= minimumTwoColumnWidth
    }

    static func canAddTask(isCompleted: Bool, hasFocusEntry: Bool) -> Bool {
        !isCompleted && !hasFocusEntry
    }

    static func subtasks(from subtasks: [FocusSubtaskItem]) -> [FocusSubtaskItem] {
        subtasks.filter { !$0.isCompleted }
    }

    static func allowsSubtaskCompletion(from source: FocusSubtaskCompletionSource) -> Bool {
        source == .checkbox
    }

    static func completionActionTitle(for subtask: FocusSubtaskItem) -> String {
        subtask.isCompleted ? "标记子任务为未完成" : "标记子任务为已完成"
    }

    static func checkboxSymbol(for subtask: FocusSubtaskItem) -> String {
        subtask.isCompleted ? "checkmark.square.fill" : "square"
    }

    static func checkboxColor(for subtask: FocusSubtaskItem) -> Color {
        subtask.isCompleted ? TaskDesignTokens.success : TaskDesignTokens.quiet
    }

    static func completionAccessibilityLabel(for subtask: FocusSubtaskItem) -> String {
        completionActionTitle(for: subtask) + "：" + subtask.title
    }

    static func subtaskRowOpacity(for subtask: FocusSubtaskItem, draggingID: UUID?) -> Double {
        if draggingID == subtask.id { return SubtaskReorderPresentation.sourceOpacity }
        return subtask.isCompleted ? 0.58 : 1
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
        HStack(spacing: 1) {
            ForEach(TaskFocusState.allCases, id: \.self) { option in
                segment(for: option)
            }
        }
        .padding(2)
        .frame(
            width: FocusPoolPresentation.statusControlWidth,
            height: FocusPoolPresentation.statusControlHeight,
            alignment: .leading
        )
        .background(
            TaskDesignTokens.settingsPanel,
            in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
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
        HStack(spacing: 5) {
            statusMarker(for: state, isSelected: isSelected)
            Text(title)
                .font(.system(size: FocusPoolPresentation.statusControlFontSize, weight: .semibold))
                .foregroundStyle(isSelected ? TaskDesignTokens.ink : TaskDesignTokens.muted)
        }
        .frame(
            width: FocusPoolPresentation.statusSegmentWidth,
            height: FocusPoolPresentation.statusSegmentHeight
        )
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                    .fill(TaskDesignTokens.raised)
                    .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusMarker(for state: TaskFocusState, isSelected: Bool) -> some View {
        let color = FocusStatePresentation.selectionColor(for: state)
        if FocusPoolPresentation.markerStyle(isSelected: isSelected) == .filled {
            ZStack {
                Circle()
                    .fill(color)
                signalLensDotMatrix
            }
            .frame(
                width: FocusPoolPresentation.selectedStatusMarkerSize,
                height: FocusPoolPresentation.selectedStatusMarkerSize
            )
        } else {
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(
                    width: FocusPoolPresentation.unselectedStatusMarkerSize,
                    height: FocusPoolPresentation.unselectedStatusMarkerSize
                )
        }
    }

    private var signalLensDotMatrix: some View {
        VStack(spacing: 0.9) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 0.9) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.52))
                            .frame(width: 1.2, height: 1.2)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FocusEntryColumnsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        precondition(subviews.count == 3, "Focus entry layout requires left column, divider, and subtask column")

        let availableWidth = resolvedWidth(for: proposal, subviews: subviews)
        if let widths = FocusPoolPresentation.columnWidths(for: availableWidth) {
            let leftSize = subviews[0].sizeThatFits(.init(width: widths.left, height: nil))
            let dividerSize = subviews[1].sizeThatFits(.init(width: FocusPoolPresentation.dividerWidth, height: nil))
            let rightSize = subviews[2].sizeThatFits(.init(width: widths.right, height: nil))

            return CGSize(
                width: availableWidth,
                height: max(leftSize.height, dividerSize.height, rightSize.height)
            )
        }

        let leftSize = subviews[0].sizeThatFits(.init(width: availableWidth, height: nil))
        let rightSize = subviews[2].sizeThatFits(.init(width: availableWidth, height: nil))
        return CGSize(
            width: availableWidth,
            height: leftSize.height + spacing + rightSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        precondition(subviews.count == 3, "Focus entry layout requires left column, divider, and subtask column")

        let availableWidth: CGFloat
        if bounds.width.isFinite, bounds.width > 0 {
            availableWidth = bounds.width
        } else {
            availableWidth = resolvedWidth(for: proposal, subviews: subviews)
        }
        if let widths = FocusPoolPresentation.columnWidths(for: availableWidth) {
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: .init(width: widths.left, height: nil)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + widths.left + spacing, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: FocusPoolPresentation.dividerWidth, height: bounds.height)
            )
            subviews[2].place(
                at: CGPoint(
                    x: bounds.minX + widths.left + spacing + FocusPoolPresentation.dividerWidth + spacing,
                    y: bounds.minY
                ),
                anchor: .topLeading,
                proposal: .init(width: widths.right, height: nil)
            )
            return
        }

        let leftSize = subviews[0].sizeThatFits(.init(width: availableWidth, height: nil))
        subviews[0].place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: .init(width: availableWidth, height: nil)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX + 10_000, y: bounds.minY),
            anchor: .topLeading,
            proposal: .zero
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + leftSize.height + spacing),
            anchor: .topLeading,
            proposal: .init(width: availableWidth, height: nil)
        )
    }

    private func resolvedWidth(
        for proposal: ProposedViewSize,
        subviews: Subviews,
        fallbackWidth: CGFloat? = nil
    ) -> CGFloat {
        let proposedWidth = proposal.width
        if let proposedWidth, proposedWidth.isFinite, proposedWidth > 0 {
            return proposedWidth
        }
        if let fallbackWidth, fallbackWidth.isFinite, fallbackWidth > 0 {
            return fallbackWidth
        }
        return max(FocusPoolPresentation.minimumTwoColumnWidth, idealWidth(for: subviews))
    }

    private func idealWidth(for subviews: Subviews) -> CGFloat {
        subviews.reduce(CGFloat.zero) { partialWidth, subview in
            partialWidth + subview.sizeThatFits(.unspecified).width
        } + spacing * 2
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
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(prioritySortedEntries, id: \.id) { entry in
                            FocusEntryRow(
                                entry: entry,
                                onRemove: { remove(entry) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(FocusPoolPresentation.pageTitle)
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
    @StateObject private var reorderCoordinator = SubtaskReorderCoordinator()
    @State private var subtaskFrames: [UUID: CGRect] = [:]
    @State private var errorMessage: String?

    init(entry: FocusEntry, onRemove: @escaping () -> Void) {
        self.entry = entry
        self.onRemove = onRemove
        _state = State(initialValue: entry.state)
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        FocusEntryColumnsLayout(spacing: FocusPoolPresentation.cardColumnSpacing) {
            leftColumn

            Rectangle()
                .fill(TaskDesignTokens.line)
                .frame(width: FocusPoolPresentation.dividerWidth)
                .accessibilityHidden(true)

            subtasksColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .onPreferenceChange(SubtaskReorderFramePreferenceKey.self) { subtaskFrames = $0 }
        .onDisappear { reorderCoordinator.cancel() }
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

    private var subtasksColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("未完成子任务")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Text("\(subtasks.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Spacer(minLength: 0)
            }

            if subtasks.isEmpty {
                Text("暂无子任务")
                    .font(.system(size: 11))
                    .foregroundStyle(TaskDesignTokens.quiet)
            } else {
                ForEach(subtasks) { subtask in
                    subtaskRow(subtask)
                }
            }

            if entry.task != nil {
                addSubtaskInput
            }
        }
        .frame(minWidth: FocusPoolPresentation.subtaskColumnMinWidth, maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: SubtaskReorderPresentation.reorderDuration), value: subtasks)
    }

    private func subtaskRow(_ subtask: FocusSubtaskItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                toggleSubtaskCompletion(subtask.id, from: .checkbox)
            } label: {
                Image(systemName: FocusPoolPresentation.checkboxSymbol(for: subtask))
                    .font(.system(size: 13))
                    .foregroundStyle(FocusPoolPresentation.checkboxColor(for: subtask))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24, alignment: .topLeading)
            .contentShape(Rectangle())
            .help(FocusPoolPresentation.completionActionTitle(for: subtask))
            .accessibilityLabel(FocusPoolPresentation.completionAccessibilityLabel(for: subtask))

            FocusSubtaskTitleEditor(
                subtask: subtask,
                isCompleted: subtask.isCompleted,
                onSave: { id, title in
                    try updateSubtaskTitle(id, title: title)
                },
                onFailure: { errorMessage = $0.localizedDescription }
            )

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .gesture(reorderGesture(for: subtask.id))
                .help("拖动排序")
                .accessibilityLabel("拖动排序")
        }
        .opacity(FocusPoolPresentation.subtaskRowOpacity(for: subtask, draggingID: reorderCoordinator.sourceID))
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SubtaskReorderFramePreferenceKey.self,
                    value: [subtask.id: proxy.frame(in: .global)]
                )
            }
        }
        .overlay(alignment: .top) {
            if reorderCoordinator.insertionLocation == .before(subtask.id) {
                SubtaskReorderInsertionIndicator()
            }
        }
        .overlay(alignment: .bottom) {
            if reorderCoordinator.insertionLocation == .after(subtask.id) {
                SubtaskReorderInsertionIndicator()
            }
        }
    }

    private var addSubtaskInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(width: 18, height: 18)

            TextField("添加子任务", text: $newSubtaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: FocusPoolPresentation.subtaskTitleFontSize))
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

    private var subtasks: [FocusSubtaskItem] {
        FocusPoolPresentation.subtasks(
            from: entry.task?.subtasks.sorted { $0.order < $1.order }.map {
                FocusSubtaskItem(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
            } ?? []
        )
    }

    private func toggleSubtaskCompletion(_ id: UUID, from source: FocusSubtaskCompletionSource) {
        guard FocusPoolPresentation.allowsSubtaskCompletion(from: source),
              let subtask = entry.task?.subtasks.first(where: { $0.id == id }) else { return }
        do {
            try TaskRepository(context: modelContext).setSubtaskCompleted(subtask, isCompleted: !subtask.isCompleted)
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

    private func reorderGesture(for id: UUID) -> some Gesture {
        DragGesture(minimumDistance: SubtaskReorderPresentation.dragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                if reorderCoordinator.sourceID != id {
                    reorderCoordinator.begin(sourceID: id)
                }
                reorderCoordinator.update(
                    location: value.location,
                    orderedIDs: reorderableSubtaskIDs(for: id),
                    frames: subtaskFrames
                )
            }
            .onEnded { value in
                reorderCoordinator.update(
                    location: value.location,
                    orderedIDs: reorderableSubtaskIDs(for: id),
                    frames: subtaskFrames
                )
                guard let move = reorderCoordinator.complete() else { return }
                apply(move)
            }
    }

    private func reorderableSubtaskIDs(for sourceID: UUID) -> [UUID] {
        guard let source = subtasks.first(where: { $0.id == sourceID }) else { return [] }
        return subtasks
            .filter { $0.isCompleted == source.isCompleted }
            .map(\.id)
    }

    private func apply(_ move: SubtaskReorderMove) {
        guard let task = entry.task,
              let source = task.subtasks.first(where: { $0.id == move.sourceID }) else {
            return
        }
        let destinationID: UUID
        let isAfter: Bool
        switch move.insertionLocation {
        case .before(let id):
            destinationID = id
            isAfter = false
        case .after(let id):
            destinationID = id
            isAfter = true
        }
        guard let destination = task.subtasks.first(where: { $0.id == destinationID }),
              source.id != destination.id else {
            return
        }

        do {
            let repository = TaskRepository(context: modelContext)
            if isAfter {
                try repository.moveSubtask(source, after: destination)
            } else {
                try repository.moveSubtask(source, before: destination)
            }
        } catch {
            errorMessage = error.localizedDescription
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
    let isCompleted: Bool
    let onSave: (UUID, String) throws -> Void
    let onFailure: (Error) -> Void

    @State private var title: String
    @State private var persistedTitle: String
    @FocusState private var isFocused: Bool

    init(
        subtask: FocusSubtaskItem,
        isCompleted: Bool,
        onSave: @escaping (UUID, String) throws -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.subtask = subtask
        self.isCompleted = isCompleted
        self.onSave = onSave
        self.onFailure = onFailure
        _title = State(initialValue: subtask.title)
        _persistedTitle = State(initialValue: subtask.title)
    }

    var body: some View {
        TextField("子任务", text: $title, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: FocusPoolPresentation.subtaskTitleFontSize))
            .foregroundStyle(isCompleted ? TaskDesignTokens.quiet : TaskDesignTokens.muted)
            .strikethrough(isCompleted)
            .lineLimit(1...)
            .fixedSize(horizontal: false, vertical: true)
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
            .accessibilityValue(isCompleted ? "已完成" : "未完成")
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
