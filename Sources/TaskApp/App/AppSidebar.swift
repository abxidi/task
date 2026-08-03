import SwiftData
import SwiftUI
import TaskPersistence

struct AppSidebar: View {
    @Binding var selection: AppRoute?
    @Binding var listScope: TaskListScope?
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt)
    private var projects: [Project]
    @Query private var allTasks: [TaskItem]
    @Query private var focusEntries: [FocusEntry]
    var isAIConfigured: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 8)
                .padding(.top, 18)
                .padding(.bottom, 19)

            sectionLabel("工作台")
            navRow(.priorityMap, title: "优先级地图", symbol: "square.grid.3x3", count: openCount)
            navRow(.taskList, title: "任务列表", symbol: "checkmark.circle", count: openCount)
            navRow(.focusPool, title: "正在做", symbol: "scope", count: focusEntries.count)
            navRow(.projectBoard, title: "项目看板", symbol: "rectangle.3.group")
            navRow(.insights, title: "数据洞察", symbol: "chart.xyaxis.line")

            sectionLabel("快捷筛选")
            filterRow(.today, title: "今天", symbol: "sun.max", count: todayCount)
            filterRow(.nextSevenDays, title: "未来 7 天", symbol: "calendar")
            filterRow(.all, title: "全部任务", symbol: "checklist", count: allTaskCount)

            if !projects.isEmpty {
                sectionLabel("项目")
                ForEach(projects, id: \.id) { project in
                    Button {
                        selection = .projectBoard
                        listScope = nil
                    } label: {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(Color(hexString: project.colorHex) ?? TaskDesignTokens.projectCoral)
                                .frame(width: 7, height: 7)
                            Text(project.name)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(TaskDesignTokens.muted)
                        .padding(.horizontal, 9)
                        .frame(height: TaskDesignTokens.navRowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                navRow(.settings, title: "设置", symbol: "gearshape")
                VStack(alignment: .leading, spacing: 3) {
                    Text("本机工作区")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.ink)
                    Text("数据仅保存在这台 Mac")
                        .font(.system(size: 9))
                        .foregroundStyle(TaskDesignTokens.quiet)
                    if isAIConfigured {
                        Text("AI 已配置")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(TaskDesignTokens.ink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(TaskDesignTokens.acid, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 9)
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TaskDesignTokens.sidebar)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            TaskLogoMark()
            Text("Task")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TaskDesignTokens.ink)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Color(hex: 0x969990))
            .padding(.horizontal, 9)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func navRow(_ route: AppRoute, title: String, symbol: String, count: Int? = nil) -> some View {
        let active = selection == route && listScope == nil
        return Button {
            selection = route
            listScope = nil
        } label: {
            rowContent(title: title, symbol: symbol, count: count, active: active)
        }
        .buttonStyle(.plain)
    }

    private func filterRow(_ scope: TaskListScope, title: String, symbol: String, count: Int? = nil) -> some View {
        let active = selection == .taskList && listScope == scope
        return Button {
            selection = .taskList
            listScope = scope
        } label: {
            rowContent(title: title, symbol: symbol, count: count, active: active)
        }
        .buttonStyle(.plain)
    }

    private func rowContent(title: String, symbol: String, count: Int?, active: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? TaskDesignTokens.acid : TaskDesignTokens.quiet)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
            Spacer(minLength: 0)
            if let count {
                Text("\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        active ? Color(hex: 0x3B3F37) : Color(hex: 0x737970).opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(active ? TaskDesignTokens.acid : TaskDesignTokens.muted)
            }
        }
        .foregroundStyle(active ? Color.white : TaskDesignTokens.muted)
        .padding(.horizontal, 9)
        .frame(height: TaskDesignTokens.navRowHeight)
        .background(active ? TaskDesignTokens.ink : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private var openCount: Int { allTasks.filter { !$0.isCompleted }.count }
    private var allTaskCount: Int { allTasks.filter { $0.project == nil }.count }
    private var todayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return allTasks.filter { item in
            guard !item.isCompleted, let due = item.dueAt else { return false }
            return due >= start && due < end
        }.count
    }
}

extension Color {
    init?(hexString: String) {
        var raw = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
