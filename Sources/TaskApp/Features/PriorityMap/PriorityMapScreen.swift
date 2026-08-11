import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

@MainActor
final class PriorityMoveSaver: ObservableObject {
    private var pending: Task<Void, Never>?

    func schedule(_ operation: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            operation()
        }
    }
}

enum PriorityMapScreenLayout {
    static let maximumMapSide: CGFloat = 620
    static let contentMaximumWidth = maximumMapSide
    static let metricHeight: CGFloat = 32
    static let verticalPadding: CGFloat = 12
    static let headerBottomSpacing: CGFloat = 8
    static let metricsBottomSpacing: CGFloat = 8
    static let toolbarBottomSpacing: CGFloat = 4

    static func mapSide(for availableSize: CGSize) -> CGFloat {
        min(availableSize.width, availableSize.height, maximumMapSide)
    }
}

struct PriorityMapScreen: View {
    var isAIConfigured: Bool = false
    var onCreateTask: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taskEditorCoordinator: TaskEditorPresentationCoordinator
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted }, sort: \TaskItem.createdAt)
    private var tasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("dailyCapacityMinutes") private var capacityMinutes = 480
    @State private var selection: TaskItem?
    @StateObject private var saver = PriorityMoveSaver()
    @State private var filter: PriorityMapScope = .all
    @State private var selectedTagNames: Set<String> = []
    @State private var isFilterPresented = false
    @State private var keyboardFocusRequest = 0

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(
                    eyebrow: Date.now.formatted(.dateTime.year().month().day().weekday(.wide)),
                    title: "把精力留给重要的事",
                    primaryActionTitle: "新任务",
                    primaryAction: onCreateTask,
                    secondaryActionTitle: "筛选",
                    secondaryAction: { isFilterPresented.toggle() }
                )
                .popover(isPresented: $isFilterPresented, arrowEdge: .top) {
                    PriorityMapFilterPopover(tags: tags, selectedTagNames: $selectedTagNames)
                        .frame(width: 220)
                }
                .padding(.bottom, PriorityMapScreenLayout.headerBottomSpacing)

                mapMetrics
                    .padding(.bottom, PriorityMapScreenLayout.metricsBottomSpacing)

                HStack {
                    HStack(spacing: 2) {
                        ForEach(PriorityMapScope.allCases, id: \.self) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(item.rawValue)
                                    .font(.system(size: 9, weight: filter == item ? .bold : .regular))
                                    .foregroundStyle(filter == item ? TaskDesignTokens.ink : TaskDesignTokens.quiet)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(filter == item ? TaskDesignTokens.raised : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))

                    Spacer()
                    Text("颜色 = 紧急度 · 数字 = 重要度")
                        .font(.system(size: 9))
                        .foregroundStyle(TaskDesignTokens.quiet)
                }
                .padding(.bottom, PriorityMapScreenLayout.toolbarBottomSpacing)

                GeometryReader { proxy in
                    let side = PriorityMapScreenLayout.mapSide(for: proxy.size)

                    ZStack {
                        if filteredTasks.isEmpty {
                            PriorityMapView(tasks: [], selection: $selection, onMove: move)
                            Text("还没有任务")
                                .font(.headline)
                                .foregroundStyle(TaskDesignTokens.muted)
                        } else {
                            PriorityMapView(
                                tasks: filteredTasks,
                                selection: $selection,
                                onMove: move,
                                onInteraction: requestKeyboardFocus
                            )
                        }

                        PriorityMapKeyboardFocusView(
                            focusRequest: keyboardFocusRequest,
                            onMove: handleMoveCommand
                        )
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                    }
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, PriorityMapScreenLayout.verticalPadding)
            .frame(maxWidth: PriorityMapScreenLayout.contentMaximumWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TaskDesignTokens.canvas)

            inspector
                .frame(width: TaskDesignTokens.inspectorWidth)
                .overlay(alignment: .leading) {
                    Rectangle().fill(TaskDesignTokens.line).frame(width: 1)
                }

            if isAIConfigured {
                AIPlanningPanel(
                    tasks: filteredTasks,
                    capacityMinutes: capacityMinutes,
                    range: Date.now...Date.now.addingTimeInterval(7 * 86_400)
                )
                .frame(width: 280)
                .overlay(alignment: .leading) {
                    Rectangle().fill(TaskDesignTokens.line).frame(width: 1)
                }
            }
        }
        .onAppear {
            TaskTagDefaults.ensurePersisted(in: modelContext)
            if selection == nil {
                selection = filteredTasks.first
            }
        }
        .onChange(of: filter) { _, _ in
            selection = filteredTasks.first
        }
        .onChange(of: selectedTagNames) { _, _ in
            selection = filteredTasks.first
        }
    }

    private var filteredTasks: [TaskItem] {
        PriorityMapTaskFilter.tasks(from: tasks, scope: filter, selectedTagNames: selectedTagNames)
    }

    private var mapMetrics: some View {
        let mapTasks = filteredTasks
        let actNow = mapTasks.filter {
            PriorityCoordinate(uncheckedUrgency: $0.urgency, importance: $0.importance).quadrant == .actNow
        }.count
        let planned = mapTasks.compactMap(\.estimatedMinutes).reduce(0, +)
        let metrics = PlanMetricsCalculator.calculate(
            tasks: mapTasks.map {
                MetricsTask(
                    id: $0.id,
                    coordinate: .init(uncheckedUrgency: $0.urgency, importance: $0.importance),
                    dueAt: $0.dueAt,
                    estimatedMinutes: $0.estimatedMinutes,
                    isCompleted: $0.isCompleted,
                    completedAt: $0.completedAt
                )
            },
            range: Date.now...Date.now.addingTimeInterval(7 * 86_400),
            capacityMinutes: capacityMinutes,
            now: .now
        )

        return HStack(spacing: 1) {
            metricCell(title: "本周任务", value: "\(mapTasks.count)", note: nil)
            metricCell(title: "立即处理", value: "\(actNow)", note: mapTasks.isEmpty ? nil : "\(Int((Double(actNow) / Double(max(mapTasks.count, 1))) * 100))%")
            metricCell(title: "计划投入", value: String(format: "%.0fh", Double(planned) / 60), note: "可控")
            metricCell(title: "计划健康度", value: "\(metrics.healthScore)", note: "/ 100")
        }
        .background(TaskDesignTokens.line, in: RoundedRectangle(cornerRadius: 7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TaskDesignTokens.line, lineWidth: 1))
    }

    private func metricCell(title: String, value: String, note: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(TaskDesignTokens.quiet)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(TaskDesignTokens.ink)
                if let note {
                    Text(note)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(TaskDesignTokens.success)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: PriorityMapScreenLayout.metricHeight,
            alignment: .leading
        )
        .padding(.horizontal, 10)
        .background(TaskDesignTokens.raised)
    }

    @ViewBuilder
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("任务详情")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.ink)
                Spacer()
                if isAIConfigured {
                    Text("● AI 已连接")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.success)
                }
            }
            .padding(.horizontal, 17)
            .frame(height: 54)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(hex: 0xE1E1DB)).frame(height: 1)
            }

            if let selection {
                let coordinate = PriorityCoordinate(uncheckedUrgency: selection.urgency, importance: selection.importance)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(coordinate.quadrant.displayName)\(selection.project.map { " · \($0.name)" } ?? "")")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(TaskDesignTokens.zoneActFG)
                            .padding(.bottom, 8)

                        Text(selection.title)
                            .font(TaskDesignTokens.inspectorTitleFont)
                            .foregroundStyle(TaskDesignTokens.ink)
                            .padding(.bottom, 12)

                        if !selection.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(selection.tags, id: \.id) { tag in
                                        TaskTagPill(name: tag.name)
                                    }
                                }
                            }
                            .taskSubtleScrollIndicators()
                            .padding(.bottom, 12)
                        }

                        HStack(spacing: 6) {
                            if let due = selection.dueAt {
                                pill(due.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let minutes = selection.estimatedMinutes {
                                pill("预计 \(minutes) 分")
                            }
                            if selection.dueAt == nil && selection.estimatedMinutes == nil {
                                pill("未设置日期")
                            }
                        }
                        .padding(.bottom, 16)

                        HStack(spacing: 7) {
                            scoreCard(title: "紧急度", value: signed(selection.urgency))
                            scoreCard(title: "重要度", value: signed(selection.importance))
                        }
                        .padding(.bottom, 16)

                        TaskChromeButton(title: "打开任务", style: .primary) {
                            taskEditorCoordinator.present(.edit(selection))
                        }
                        .frame(maxWidth: .infinity)

                        if !selection.details.isEmpty {
                            Text(selection.details)
                                .font(.system(size: 11))
                                .foregroundStyle(TaskDesignTokens.muted)
                                .padding(.top, 16)
                                .lineSpacing(4)
                        }

                        let subtasks = SubtaskOrder.incompleteFirst(
                            selection.subtasks.sorted { $0.order < $1.order },
                            isCompleted: \.isCompleted
                        )
                        if !subtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("子任务 · \(subtasks.filter(\.isCompleted).count) / \(subtasks.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.top, 18)
                                    .padding(.bottom, 4)
                                ForEach(subtasks, id: \.id) { subtask in
                                    HStack(spacing: 8) {
                                        Image(systemName: subtask.isCompleted ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 12))
                                            .foregroundStyle(TaskDesignTokens.quiet)
                                        Text(subtask.title)
                                            .font(.system(size: 11))
                                            .foregroundStyle(TaskDesignTokens.muted)
                                            .strikethrough(subtask.isCompleted)
                                        Spacer()
                                    }
                                    .frame(minHeight: 34)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(Color(hex: 0xE5E5DF)).frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                }
                .taskSubtleScrollIndicators()
            } else {
                ContentUnavailableView("选择任务", systemImage: "hand.tap", description: Text("在地图上点击色块查看详情。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TaskDesignTokens.panel)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(TaskDesignTokens.muted)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color(hex: 0xEFEFE9), in: RoundedRectangle(cornerRadius: 5))
    }

    private func scoreCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(TaskDesignTokens.quiet)
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(TaskDesignTokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.line, lineWidth: 1))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func move(_ task: TaskItem, to coordinate: PriorityCoordinate) {
        task.urgency = coordinate.urgency
        task.importance = coordinate.importance
        task.updatedAt = .now
        selection = task
        saver.schedule {
            try? modelContext.save()
        }
    }

    private func requestKeyboardFocus() {
        keyboardFocusRequest += 1
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let selection else { return }
        var urgency = selection.urgency
        var importance = selection.importance
        switch direction {
        case .left: urgency -= 1
        case .right: urgency += 1
        case .up: importance += 1
        case .down: importance -= 1
        @unknown default: return
        }
        move(selection, to: PriorityCoordinate.clamped(urgency: urgency, importance: importance))
    }
}
