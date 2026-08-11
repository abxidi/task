import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

enum TaskListScope: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case all
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今天"
        case .thisWeek: "本周"
        case .all: "全部任务"
        case .completed: "已完成"
        }
    }

    var allowsTaskDeletion: Bool {
        self == .completed
    }

    func allowsTaskDeletion(in lane: BoardColumn) -> Bool {
        allowsTaskDeletion || lane.isCompletionColumn
    }
}

struct TaskListScreen: View {
    var initialScope: TaskListScope? = nil
    var onCreateTask: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taskEditorCoordinator: TaskEditorPresentationCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @Query(sort: \BoardColumn.order) private var boardColumns: [BoardColumn]
    @State private var scope: TaskListScope = .all
    @State private var renamingColumn: BoardColumn?
    @State private var renameText = ""
    @StateObject private var dragCoordinator = BoardDragCoordinator()
    @State private var columnFrames: [UUID: CGRect] = [:]
    @State private var dropPlaceholderFrames: [UUID: CGRect] = [:]
    @State private var settlementToken: UUID?
    @State private var errorMessage: String?
    @State private var taskPendingDeletion: TaskItem?
    @State private var completedSearchText = ""
    @State private var completedSort: CompletedTaskSort = .completionTime

    var body: some View {
        GeometryReader { geometry in
            taskListContent
                .overlay(alignment: .topLeading) {
                    dragOverlay(in: geometry)
                }
                .onPreferenceChange(BoardColumnFramePreferenceKey.self) { columnFrames = $0 }
                .onPreferenceChange(BoardDropPlaceholderFramePreferenceKey.self) { dropPlaceholderFrames = $0 }
        }
        .onExitCommand {
            guard dragCoordinator.taskID != nil else { return }
            settleDrag(.cancel)
        }
        .sheet(item: $renamingColumn) { lane in
            renameSheet(for: lane)
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "删除任务？",
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { if !$0 { taskPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: taskPendingDeletion
        ) { task in
            Button("删除", role: .destructive) {
                delete(task)
            }
        } message: { task in
            Text("“\(task.title)”将从本机永久删除。")
        }
        .onDisappear {
            settlementToken = nil
            dragCoordinator.cancel()
        }
    }

    private var taskListContent: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "任务列表 · \(scope.title)",
                title: "任务列表",
                primaryActionTitle: "新任务",
                primaryAction: {
                    if let lane = lanes.first {
                        taskEditorCoordinator.present(.createInColumn(lane.id))
                    }
                }
            )
            .padding(.horizontal, 26)
            .padding(.top, 25)
            .padding(.bottom, 16)

            scopePicker

            if scope == .completed {
                CompletedTaskGrid(
                    tasks: completedTasks,
                    searchText: $completedSearchText,
                    sort: $completedSort,
                    onOpenTask: { taskEditorCoordinator.present(.edit($0)) },
                    onToggleTask: toggle,
                    onDeleteTask: { taskPendingDeletion = $0 }
                )
            } else if lanes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(lanes, id: \.id) { lane in
                            BoardColumnView(
                                column: lane,
                                tasks: tasks(in: lane),
                                onAddTask: { taskEditorCoordinator.present(.createInColumn(lane.id)) },
                                onRename: {
                                    renameText = lane.name
                                    renamingColumn = lane
                                },
                                onArchive: {},
                                onDragChanged: { updateDrag(at: $0) },
                                onDragEnded: { finishDrag(at: $0) },
                                onOpenTask: { taskEditorCoordinator.present(.edit($0)) },
                                onToggleTask: toggle,
                                onDelete: scope.allowsTaskDeletion(in: lane) ? { taskPendingDeletion = $0 } : nil,
                                draggedTask: draggedTask,
                                targetPlaceholderIndex: targetPlaceholderIndex(for: lane),
                                dragCoordinator: dragCoordinator
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
        .onAppear {
            _ = try? TaskListLaneRepository(context: modelContext).defaultLanes()
            if let initialScope { scope = initialScope }
        }
        .onChange(of: initialScope) { _, newValue in
            if let newValue { scope = newValue }
        }
    }

    private func renameSheet(for lane: BoardColumn) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名泳道")
                .font(TaskDesignTokens.pageTitleFont)
            TextField("泳道名称", text: $renameText)
                .textFieldStyle(.roundedBorder)
            HStack {
                TaskChromeButton(title: "取消") { renamingColumn = nil }
                Spacer()
                TaskChromeButton(title: "保存", style: .primary) {
                    try? ProjectRepository(context: modelContext).renameColumn(lane, to: renameText)
                    renamingColumn = nil
                }
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(TaskDesignTokens.panel)
    }

    private var scopePicker: some View {
        HStack(spacing: 2) {
            ForEach(TaskListScope.allCases) { item in
                Button {
                    scope = item
                } label: {
                    Text(item.title)
                        .font(.system(size: 10, weight: scope == item ? .bold : .regular))
                        .foregroundStyle(scope == item ? TaskDesignTokens.ink : TaskDesignTokens.quiet)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(scope == item ? TaskDesignTokens.raised : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(3)
        .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    private var lanes: [BoardColumn] {
        boardColumns.filter { $0.project == nil }.sorted { $0.order < $1.order }
    }

    private var filteredTasks: [TaskItem] {
        let calendar = Calendar.current
        let now = Date.now

        let filtered: [TaskItem]
        switch scope {
        case .today:
            filtered = allTasks.filter {
                !$0.isCompleted && TaskListDateFilter.matches(
                    dueAt: $0.dueAt,
                    in: .today,
                    now: now,
                    calendar: calendar
                )
            }
        case .thisWeek:
            filtered = allTasks.filter {
                !$0.isCompleted && TaskListDateFilter.matches(
                    dueAt: $0.dueAt,
                    in: .thisWeek,
                    now: now,
                    calendar: calendar
                )
            }
        case .all:
            filtered = allTasks.filter { $0.project == nil }
        case .completed:
            filtered = allTasks.filter { $0.isCompleted && $0.project == nil }
        }

        return filtered.sorted(by: sortsByPriority)
    }

    private var completedTasks: [TaskItem] {
        allTasks
            .filter { $0.isCompleted && $0.project == nil }
            .filter { CompletedTaskPresentation.matches($0, query: completedSearchText) }
            .sorted(by: completedSort == .completionTime
                ? CompletedTaskPresentation.sortsByCompletionTime
                : CompletedTaskPresentation.sortsByCreationTime)
    }

    private func tasks(in lane: BoardColumn) -> [TaskItem] {
        filteredTasks.filter { task in
            task.boardColumn?.id == lane.id || (lane.order == 0 && task.boardColumn == nil)
        }
    }

    private var draggedTask: TaskItem? {
        guard let taskID = dragCoordinator.taskID else { return nil }
        return allTasks.first { $0.id == taskID }
    }

    private func targetPlaceholderIndex(for lane: BoardColumn) -> Int? {
        guard
            let session = dragCoordinator.session,
            session.targetColumnID == lane.id,
            BoardDragPresentation.showsTargetPlaceholder(
                sourceColumnID: session.sourceColumnID,
                targetColumnID: session.targetColumnID
            ),
            let draggedTask
        else {
            return nil
        }
        let finalTasks = (tasks(in: lane).filter { $0.id != draggedTask.id } + [draggedTask])
            .sorted(by: sortsByPriority)
        return BoardDragPresentation.insertionIndex(
            itemID: draggedTask.id,
            sortedIDs: finalTasks.map(\.id)
        )
    }

    private func sortsByPriority(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        TaskSort.priority(
            TaskSortValue(id: lhs.id.uuidString, urgency: lhs.urgency, importance: lhs.importance, dueAt: lhs.dueAt, createdAt: lhs.createdAt),
            TaskSortValue(id: rhs.id.uuidString, urgency: rhs.urgency, importance: rhs.importance, dueAt: rhs.dueAt, createdAt: rhs.createdAt)
        )
    }

    @discardableResult
    private func move(_ taskID: UUID, to lane: BoardColumn) -> Bool {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return false }
        guard task.boardColumn?.id != lane.id else { return true }
        do {
            try BoardWorkflowService(context: modelContext).move(task, to: lane)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateDrag(at boardLocation: CGPoint) {
        guard let sourceColumnID = dragCoordinator.sourceColumnID else { return }
        let targetColumnID = columnID(at: boardLocation) ?? dragCoordinator.targetColumnID ?? sourceColumnID
        dragCoordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
    }

    private func finishDrag(at boardLocation: CGPoint) {
        let targetColumnID = columnID(at: boardLocation)
        if let targetColumnID {
            dragCoordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
        }
        settleDrag(BoardDragPresentation.completionDecision(
            taskID: dragCoordinator.taskID,
            sourceColumnID: dragCoordinator.sourceColumnID,
            targetColumnID: targetColumnID
        ))
    }

    private func settleDrag(_ decision: BoardDragCompletionDecision) {
        guard let session = dragCoordinator.session else { return }
        let token = UUID()
        settlementToken = token

        guard !reduceMotion else {
            completeDrag(decision, taskID: session.taskID, token: token)
            return
        }

        let destinationFrame: CGRect
        if case .move(let move) = decision {
            destinationFrame = dropPlaceholderFrames[move.targetColumnID]
                ?? columnFrames[move.targetColumnID]
                ?? session.sourceFrame
        } else {
            destinationFrame = session.sourceFrame
        }

        withAnimation(.easeOut(duration: BoardDragPresentation.dropDuration)) {
            dragCoordinator.settle(to: destinationFrame)
        } completion: {
            completeDrag(decision, taskID: session.taskID, token: token)
        }
    }

    private func completeDrag(_ decision: BoardDragCompletionDecision, taskID: UUID, token: UUID) {
        guard settlementToken == token, dragCoordinator.taskID == taskID else { return }

        switch decision {
        case .move(let dragMove):
            guard let lane = lanes.first(where: { $0.id == dragMove.targetColumnID }) else {
                returnDragToSource(taskID: taskID)
                return
            }
            guard BoardDragPresentation.completeHandoff(coordinator: dragCoordinator, performMove: {
                move(dragMove.taskID, to: lane)
            }) else {
                returnDragToSource(taskID: taskID)
                return
            }
            settlementToken = nil
        case .cancel, .noMove:
            finishDragPresentation()
        }
    }

    private func returnDragToSource(taskID: UUID) {
        guard let session = dragCoordinator.session, session.taskID == taskID else { return }
        let token = UUID()
        settlementToken = token
        guard !reduceMotion else {
            finishDragPresentation()
            return
        }
        withAnimation(.easeOut(duration: BoardDragPresentation.dropDuration)) {
            dragCoordinator.settle(to: session.sourceFrame)
        } completion: {
            guard settlementToken == token, dragCoordinator.taskID == taskID else { return }
            finishDragPresentation()
        }
    }

    private func finishDragPresentation() {
        settlementToken = nil
        withAnimation(.linear(duration: 0.08)) {
            dragCoordinator.complete()
        }
    }

    private func columnID(at boardLocation: CGPoint) -> UUID? {
        columnFrames.first { $0.value.contains(boardLocation) }?.key
    }

    @ViewBuilder
    private func dragOverlay(in geometry: GeometryProxy) -> some View {
        if
            let session = dragCoordinator.session,
            let task = allTasks.first(where: { $0.id == session.taskID })
        {
            let offset = BoardDragPresentation.overlayOffset(
                for: session.boardLocation,
                grabOffset: session.grabOffset,
                in: geometry.frame(in: .global)
            )
            BoardTaskCard(task: task)
                .frame(width: max(session.sourceFrame.width, 1), alignment: .leading)
                .offset(x: offset.width, y: offset.height)
                .scaleEffect(
                    !reduceMotion && session.phase == .dragging ? BoardDragPresentation.liftedScale : 1,
                    anchor: .topLeading
                )
                .shadow(
                    color: .black.opacity(session.phase == .dragging ? 0.18 : 0.08),
                    radius: session.phase == .dragging ? 12 : 3,
                    y: session.phase == .dragging ? 6 : 1
                )
                .animation(
                    .easeOut(duration: BoardDragPresentation.liftDuration),
                    value: session.phase
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading))
                )
                .zIndex(1_000)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func toggle(_ task: TaskItem) {
        try? TaskRepository(context: modelContext).setCompleted(task, isCompleted: !task.isCompleted)
    }

    private func delete(_ task: TaskItem) {
        do {
            try TaskRepository(context: modelContext).deleteTask(task)
            taskPendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
