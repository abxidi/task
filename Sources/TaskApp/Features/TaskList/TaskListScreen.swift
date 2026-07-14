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
    @State private var scope: TaskListScope = .inbox
    @State private var quickTitle = ""
    @State private var editingTask: TaskItem?

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                eyebrow: "任务列表 · \(scope.title)",
                title: scope.title,
                primaryActionTitle: "新任务",
                primaryAction: onCreateTask
            )
            .padding(.horizontal, 26)
            .padding(.top, 25)
            .padding(.bottom, 16)

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
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                TextField("输入标题，回车快速创建", text: $quickTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
                    .onSubmit(createQuickTask)
                TaskChromeButton(title: "创建", style: .primary, action: createQuickTask)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)

            List(filteredTasks, id: \.id) { item in
                TaskListRow(item: item) {
                    toggle(item)
                } onOpen: {
                    editingTask = item
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 26)
            .background(TaskDesignTokens.canvas)
        }
        .background(TaskDesignTokens.canvas)
        .onAppear {
            if let initialScope {
                scope = initialScope
            }
        }
        .onChange(of: initialScope) { _, newValue in
            if let newValue {
                scope = newValue
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(mode: .edit(task))
        }
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
            filtered = allTasks.filter { item in
                guard !item.isCompleted, let due = item.dueAt else { return false }
                return due >= startOfToday && due < endOfToday
            }
        case .nextSevenDays:
            filtered = allTasks.filter { item in
                guard !item.isCompleted, let due = item.dueAt else { return false }
                return due >= startOfToday && due < endOfWeek
            }
        case .all:
            filtered = allTasks.filter { !$0.isCompleted }
        case .completed:
            filtered = allTasks.filter(\.isCompleted)
        }

        return filtered.sorted {
            TaskSort.priority(
                TaskSortValue(id: $0.id.uuidString, urgency: $0.urgency, importance: $0.importance, dueAt: $0.dueAt, createdAt: $0.createdAt),
                TaskSortValue(id: $1.id.uuidString, urgency: $1.urgency, importance: $1.importance, dueAt: $1.dueAt, createdAt: $1.createdAt)
            )
        }
    }

    private func createQuickTask() {
        let repository = TaskRepository(context: modelContext)
        do {
            try repository.createTask(title: quickTitle)
            quickTitle = ""
        } catch {
            // Keep field for correction.
        }
    }

    private func toggle(_ item: TaskItem) {
        let repository = TaskRepository(context: modelContext)
        try? repository.setCompleted(item, isCompleted: !item.isCompleted)
    }
}

private struct TaskListRow: View {
    let item: TaskItem
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isCompleted ? TaskDesignTokens.success : TaskDesignTokens.quiet)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "标记为未完成" : "标记为已完成")

            PriorityMarkerView(
                coordinate: .init(uncheckedUrgency: item.urgency, importance: item.importance),
                title: item.title,
                isSelected: false
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.ink)
                    .strikethrough(item.isCompleted)
                HStack(spacing: 8) {
                    if let dueAt = item.dueAt {
                        Text(dueAt, style: .date)
                    }
                    if let project = item.project {
                        Text(project.name)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(TaskDesignTokens.quiet)
            }
            Spacer()
        }
        .padding(12)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}
