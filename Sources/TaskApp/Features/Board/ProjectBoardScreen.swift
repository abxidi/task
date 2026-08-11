import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

struct ProjectBoardScreen: View {
    var isAIConfigured: Bool = false
    var onCreateTask: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taskEditorCoordinator: TaskEditorPresentationCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.createdAt)
    private var projects: [Project]
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @AppStorage("dailyCapacityMinutes") private var capacityMinutes = 480

    @State private var selectedProjectID: UUID?
    @State private var errorMessage: String?
    @State private var isCreatingProject = false
    @State private var newProjectName = ""
    @State private var renamingColumn: BoardColumn?
    @State private var renameText = ""
    @State private var rangeDays = 7
    @StateObject private var dragCoordinator = BoardDragCoordinator()
    @State private var columnFrames: [UUID: CGRect] = [:]
    @State private var dropPlaceholderFrames: [UUID: CGRect] = [:]
    @State private var settlementToken: UUID?

    var body: some View {
        GeometryReader { geometry in
            AnyView(boardLayout)
                .overlay(alignment: .topLeading) {
                    dragOverlay(in: geometry)
                }
                .onPreferenceChange(BoardColumnFramePreferenceKey.self) { columnFrames = $0 }
                .onPreferenceChange(BoardDropPlaceholderFramePreferenceKey.self) { dropPlaceholderFrames = $0 }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $isCreatingProject) {
            VStack(alignment: .leading, spacing: 16) {
                Text("新建项目")
                    .font(TaskDesignTokens.pageTitleFont)
                TextField("项目名称", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TaskChromeButton(title: "取消") { isCreatingProject = false }
                    Spacer()
                    TaskChromeButton(title: "创建", style: .primary, action: createProject)
                        .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 360)
            .background(TaskDesignTokens.panel)
        }
        .sheet(item: $renamingColumn) { column in
            VStack(alignment: .leading, spacing: 16) {
                Text("重命名列")
                    .font(.title3.weight(.semibold))
                TextField("列名", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TaskChromeButton(title: "取消") { renamingColumn = nil }
                    Spacer()
                    TaskChromeButton(title: "保存", style: .primary) {
                        try? ProjectRepository(context: modelContext).renameColumn(column, to: renameText)
                        renamingColumn = nil
                    }
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(TaskDesignTokens.panel)
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
        .onExitCommand {
            guard dragCoordinator.taskID != nil else { return }
            settleDrag(.cancel, in: selectedProject)
        }
        .onDisappear {
            settlementToken = nil
            dragCoordinator.cancel()
        }
    }

    private var boardLayout: some View {
        HStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(
                        eyebrow: selectedProject.map { "\($0.name) · 近 \(rangeDays) 天" } ?? "项目看板",
                        title: selectedProject == nil ? "本周推进看板" : "本周推进看板",
                        primaryActionTitle: isAIConfigured ? "AI 规划本周" : "新任务",
                        primaryAction: {
                            if isAIConfigured {
                                // AI panel already visible
                            } else {
                                onCreateTask()
                            }
                        },
                        secondaryActionTitle: "新建项目",
                        secondaryAction: {
                            newProjectName = ""
                            isCreatingProject = true
                        }
                    )
                    .padding(.bottom, 16)

                    HStack(spacing: 12) {
                        Picker("项目", selection: $selectedProjectID) {
                            ForEach(projects, id: \.id) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .frame(width: 180)
                        Picker("范围", selection: $rangeDays) {
                            Text("本周").tag(7)
                            Text("本月").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        Spacer()
                    }
                    .padding(.bottom, 12)

                    if let project = selectedProject {
                        MetricsStrip(metrics: metrics(for: project))
                            .padding(.bottom, 15)

                        HStack(alignment: .top, spacing: 10) {
                            CompletionTrendChart(points: trend(for: project))
                                .frame(maxWidth: .infinity)
                            QuadrantDistributionChart(distribution: quadrants(for: project))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.bottom, 15)

                        HStack {
                            Text("任务流")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TaskDesignTokens.ink)
                            Spacer()
                            Text("按优先级排序")
                                .font(.system(size: 8))
                                .foregroundStyle(TaskDesignTokens.muted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(.bottom, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(sortedColumns(project), id: \.id) { column in
                                    BoardColumnView(
                                        column: column,
                                        tasks: tasks(in: column, project: project),
                                        onAddTask: { taskEditorCoordinator.present(.createInColumn(column.id)) },
                                        onRename: {
                                            renamingColumn = column
                                            renameText = column.name
                                        },
                                        onArchive: {
                                            try? ProjectRepository(context: modelContext).archiveColumn(column)
                                        },
                                        onDragChanged: { updateDrag(at: $0) },
                                        onDragEnded: { finishDrag(at: $0, in: project) },
                                        draggedTask: draggedTask,
                                        targetPlaceholderIndex: targetPlaceholderIndex(for: column, project: project),
                                        dragCoordinator: dragCoordinator
                                    )
                                }
                            }
                        }
                        .taskSubtleScrollIndicators()
                    } else {
                        ContentUnavailableView("创建项目", systemImage: "rectangle.3.group", description: Text("项目看板用于推进流程。"))
                            .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 25)
            }
            .taskSubtleScrollIndicators()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TaskDesignTokens.canvas)

            if isAIConfigured, let project = selectedProject {
                AIPlanningPanel(
                    tasks: projectTasks(project).filter { !$0.isCompleted },
                    capacityMinutes: capacityMinutes,
                    range: dateRange()
                )
                .frame(width: TaskDesignTokens.inspectorWidth)
                .overlay(alignment: .leading) {
                    Rectangle().fill(TaskDesignTokens.line).frame(width: 1)
                }
            }
        }
    }

    private var selectedProject: Project? {
        projects.first { $0.id == selectedProjectID }
    }

    private func sortedColumns(_ project: Project) -> [BoardColumn] {
        project.boardColumns.sorted { $0.order < $1.order }
    }

    private func tasks(in column: BoardColumn, project: Project) -> [TaskItem] {
        allTasks
            .filter { $0.project?.id == project.id && $0.boardColumn?.id == column.id }
            .sorted { $0.manualOrder < $1.manualOrder }
    }

    private func projectTasks(_ project: Project) -> [TaskItem] {
        allTasks.filter { $0.project?.id == project.id }
    }

    private func dateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: rangeDays, to: start) ?? start.addingTimeInterval(Double(rangeDays) * 86_400)
        return start...end
    }

    private func metricsTasks(for project: Project) -> [MetricsTask<UUID>] {
        projectTasks(project).map {
            MetricsTask(
                id: $0.id,
                coordinate: .init(uncheckedUrgency: $0.urgency, importance: $0.importance),
                dueAt: $0.dueAt,
                estimatedMinutes: $0.estimatedMinutes,
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt
            )
        }
    }

    private func metrics(for project: Project) -> PlanMetrics {
        PlanMetricsCalculator.calculate(
            tasks: metricsTasks(for: project),
            range: dateRange(),
            capacityMinutes: capacityMinutes,
            now: .now
        )
    }

    private func trend(for project: Project) -> [CompletionPoint] {
        PlanMetricsCalculator.completionTrend(tasks: metricsTasks(for: project), range: dateRange())
            .map { CompletionPoint(day: $0.day, count: $0.count) }
    }

    private func quadrants(for project: Project) -> [PriorityQuadrant: Int] {
        PlanMetricsCalculator.quadrantDistribution(tasks: metricsTasks(for: project))
    }

    private var draggedTask: TaskItem? {
        guard let taskID = dragCoordinator.taskID else { return nil }
        return allTasks.first { $0.id == taskID }
    }

    private func targetPlaceholderIndex(for column: BoardColumn, project: Project) -> Int? {
        guard
            let session = dragCoordinator.session,
            session.targetColumnID == column.id,
            BoardDragPresentation.showsTargetPlaceholder(
                sourceColumnID: session.sourceColumnID,
                targetColumnID: session.targetColumnID
            ),
            let draggedTask
        else {
            return nil
        }
        let finalTasks = (tasks(in: column, project: project).filter { $0.id != draggedTask.id } + [draggedTask])
            .sorted { $0.manualOrder < $1.manualOrder }
        return BoardDragPresentation.insertionIndex(
            itemID: draggedTask.id,
            sortedIDs: finalTasks.map(\.id)
        )
    }

    @discardableResult
    private func move(_ taskID: UUID, to column: BoardColumn, project: Project) -> Bool {
        guard let task = projectTasks(project).first(where: { $0.id == taskID }) else { return false }
        guard task.boardColumn?.id != column.id else { return true }
        do {
            try BoardWorkflowService(context: modelContext).move(task, to: column)
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

    private func finishDrag(at boardLocation: CGPoint, in project: Project) {
        let targetColumnID = columnID(at: boardLocation)
        if let targetColumnID {
            dragCoordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
        }
        settleDrag(BoardDragPresentation.completionDecision(
            taskID: dragCoordinator.taskID,
            sourceColumnID: dragCoordinator.sourceColumnID,
            targetColumnID: targetColumnID
        ), in: project)
    }

    private func settleDrag(_ decision: BoardDragCompletionDecision, in project: Project?) {
        guard let session = dragCoordinator.session else { return }
        let token = UUID()
        settlementToken = token

        guard !reduceMotion else {
            completeDrag(decision, taskID: session.taskID, token: token, project: project)
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
            completeDrag(decision, taskID: session.taskID, token: token, project: project)
        }
    }

    private func completeDrag(
        _ decision: BoardDragCompletionDecision,
        taskID: UUID,
        token: UUID,
        project: Project?
    ) {
        guard settlementToken == token, dragCoordinator.taskID == taskID else { return }

        switch decision {
        case .move(let dragMove):
            guard
                let project,
                let targetColumn = sortedColumns(project).first(where: { $0.id == dragMove.targetColumnID })
            else {
                returnDragToSource(taskID: taskID)
                return
            }
            guard BoardDragPresentation.completeHandoff(coordinator: dragCoordinator, performMove: {
                move(dragMove.taskID, to: targetColumn, project: project)
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
            let globalFrame = geometry.frame(in: .global)
            let offset = BoardDragPresentation.overlayOffset(
                for: session.boardLocation,
                grabOffset: session.grabOffset,
                in: globalFrame
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

    private func createProject() {
        do {
            let project = try ProjectRepository(context: modelContext).createProject(name: newProjectName, colorHex: "#F07446")
            selectedProjectID = project.id
            isCreatingProject = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
