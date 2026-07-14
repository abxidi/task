import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

enum TaskListScope: String, CaseIterable, Identifiable {
    case inbox
    case today
    case nextSevenDays
    case all
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .inbox: "收件箱"
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

    var body: some View {
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
                                onDropTaskID: { move($0, to: lane) },
                                onAddTask: { creatingInColumn = lane },
                                onRename: {
                                    renameText = lane.name
                                    renamingColumn = lane
                                },
                                onArchive: {},
                                onOpenTask: { editingTask = $0 },
                                onToggleTask: toggle
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
        case .inbox:
            filtered = allTasks.filter { !$0.isCompleted && $0.project == nil }
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
        try? BoardWorkflowService(context: modelContext).move(task, to: lane)
    }

    private func toggle(_ task: TaskItem) {
        try? TaskRepository(context: modelContext).setCompleted(task, isCompleted: !task.isCompleted)
    }
}
