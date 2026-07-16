import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

@MainActor
final class TaskListBoardDragState: ObservableObject {
    let coordinator = BoardDragCoordinator()
}

enum TaskListScope: String, CaseIterable, Identifiable {
    case today
    case nextSevenDays
    case all
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今天"
        case .nextSevenDays: "未来 7 天"
        case .all: "全部任务"
        case .completed: "已完成"
        }
    }
}

struct TaskListScreen: View {
    var initialScope: TaskListScope? = nil
    var onCreateTask: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @Query(sort: \BoardColumn.order) private var boardColumns: [BoardColumn]
    @State private var scope: TaskListScope = .all
    @State private var editingTask: TaskItem?
    @State private var creatingInColumn: BoardColumn?
    @State private var renamingColumn: BoardColumn?
    @State private var renameText = ""
    @StateObject private var dragState = TaskListBoardDragState()
    @State private var columnFrames: [UUID: CGRect] = [:]

    var body: some View {
        GeometryReader { geometry in
            taskListContent
                .overlay(alignment: .topLeading) {
                    dragOverlay(in: geometry)
                }
                .onPreferenceChange(BoardColumnFramePreferenceKey.self) { columnFrames = $0 }
        }
        .onExitCommand {
            guard dragState.coordinator.taskID != nil else { return }
            dragState.coordinator.cancel()
        }
        .overlay {
            if let task = editingTask {
                TaskEditorOverlay(mode: .edit(task)) {
                    editingTask = nil
                }
            } else if let lane = creatingInColumn {
                TaskEditorOverlay(mode: .createInColumn(lane.id)) {
                    creatingInColumn = nil
                }
            }
        }
        .sheet(item: $renamingColumn) { lane in
            renameSheet(for: lane)
        }
    }

    private var taskListContent: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "任务列表 · (scope.title)",
                title: "任务列表",
                primaryActionTitle: "新任务",
                primaryAction: { creatingInColumn = lanes.first }
            )
            .padding(.horizontal, 26)
            .padding(.top, 25)
            .padding(.bottom, 16)

            scopePicker

            if lanes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(lanes, id: \.id) { lane in
                            BoardColumnView(
                                column: lane,
                                tasks: tasks(in: lane),
                                onAddTask: { creatingInColumn = lane },
                                onRename: {
                                    renameText = lane.name
                                    renamingColumn = lane
                                },
                                onArchive: {},
                                onDragChanged: { updateDrag(at: $0) },
                                onDragEnded: { finishDrag(at: $0) },
                                onOpenTask: { editingTask = $0 },
                                onToggleTask: toggle,
                                dragCoordinator: dragState.coordinator
                            )
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
                }
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
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now

        let filtered: [TaskItem]
        switch scope {
        case .today:
            filtered = allTasks.filter { !$0.isCompleted && ($0.dueAt.map { $0 >= startOfToday && $0 < endOfToday } ?? false) }
        case .nextSevenDays:
            filtered = allTasks.filter { !$0.isCompleted && ($0.dueAt.map { $0 >= startOfToday && $0 < endOfWeek } ?? false) }
        case .all:
            filtered = allTasks.filter { $0.project == nil }
        case .completed:
            filtered = allTasks.filter { $0.isCompleted && $0.project == nil }
        }

        return filtered.sorted {
            TaskSort.priority(
                TaskSortValue(id: $0.id.uuidString, urgency: $0.urgency, importance: $0.importance, dueAt: $0.dueAt, createdAt: $0.createdAt),
                TaskSortValue(id: $1.id.uuidString, urgency: $1.urgency, importance: $1.importance, dueAt: $1.dueAt, createdAt: $1.createdAt)
            )
        }
    }

    private func tasks(in lane: BoardColumn) -> [TaskItem] {
        filteredTasks.filter { task in
            task.boardColumn?.id == lane.id || (lane.order == 0 && task.boardColumn == nil)
        }
    }

    private func move(_ taskID: UUID, to lane: BoardColumn) {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }
        guard task.boardColumn?.id != lane.id else { return }
        try? BoardWorkflowService(context: modelContext).move(task, to: lane)
    }

    private func updateDrag(at boardLocation: CGPoint) {
        let coordinator = dragState.coordinator
        guard let sourceColumnID = coordinator.sourceColumnID else { return }
        let targetColumnID = columnID(at: boardLocation) ?? coordinator.targetColumnID ?? sourceColumnID
        coordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
    }

    private func finishDrag(at boardLocation: CGPoint) {
        let coordinator = dragState.coordinator
        guard let targetColumnID = columnID(at: boardLocation) else {
            coordinator.cancel()
            return
        }
        coordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
        if let dragMove = coordinator.finish(), let lane = lanes.first(where: { $0.id == dragMove.targetColumnID }) {
            move(dragMove.taskID, to: lane)
        }
    }

    private func columnID(at boardLocation: CGPoint) -> UUID? {
        columnFrames.first { $0.value.contains(boardLocation) }?.key
    }

    @ViewBuilder
    private func dragOverlay(in geometry: GeometryProxy) -> some View {
        if
            let session = dragState.coordinator.session,
            let task = allTasks.first(where: { $0.id == session.taskID })
        {
            let offset = BoardDragPresentation.overlayOffset(
                for: session.boardLocation,
                grabOffset: session.grabOffset,
                in: geometry.frame(in: .global)
            )
            BoardTaskCard(task: task)
                .frame(width: 248, alignment: .leading)
                .offset(x: offset.width, y: offset.height)
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func toggle(_ task: TaskItem) {
        try? TaskRepository(context: modelContext).setCompleted(task, isCompleted: !task.isCompleted)
    }
}
