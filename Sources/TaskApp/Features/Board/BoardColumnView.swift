import Foundation
import SwiftUI
import TaskPersistence

enum BoardDragPresentation {
    static let placeholderOpacity = 0.35
    static let liftDuration = 0.14
    static let dropDuration = 0.18
    static let liftedScale = 1.015
    static let targetGhostOpacity = 0.28
    static let targetTintOpacity = 0.12

    static var handoffTransaction: Transaction {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return transaction
    }

    @MainActor
    static func completeHandoff(
        coordinator: BoardDragCoordinator,
        performMove: () -> Bool
    ) -> Bool {
        withTransaction(handoffTransaction) {
            guard performMove() else { return false }
            coordinator.complete()
            return true
        }
    }

    static func sourceOpacity(isActiveSource: Bool) -> Double {
        isActiveSource ? placeholderOpacity : 1
    }

    static func placeholderIndex(requested: Int, taskCount: Int) -> Int {
        min(max(requested, 0), taskCount)
    }

    static func insertionIndex<ID: Equatable>(itemID: ID, sortedIDs: [ID]) -> Int? {
        sortedIDs.firstIndex(of: itemID)
    }

    static func showsTargetPlaceholder(sourceColumnID: UUID, targetColumnID: UUID) -> Bool {
        sourceColumnID != targetColumnID
    }

    static func overlayOffset(
        for pointerLocation: CGPoint,
        grabOffset: CGPoint,
        in overlayGlobalFrame: CGRect
    ) -> CGSize {
        CGSize(
            width: pointerLocation.x - grabOffset.x - overlayGlobalFrame.minX,
            height: pointerLocation.y - grabOffset.y - overlayGlobalFrame.minY
        )
    }

    static func completionDecision(
        taskID: UUID?,
        sourceColumnID: UUID?,
        targetColumnID: UUID?
    ) -> BoardDragCompletionDecision {
        guard let taskID, let sourceColumnID, let targetColumnID else {
            return .cancel
        }
        guard sourceColumnID != targetColumnID else {
            return .noMove
        }
        return .move(BoardDragMove(taskID: taskID, targetColumnID: targetColumnID))
    }
}

enum BoardDragCompletionDecision: Equatable {
    case cancel
    case noMove
    case move(BoardDragMove)
}

struct BoardColumnFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct BoardTaskFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct BoardDropPlaceholderFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct BoardColumnView: View {
    let column: BoardColumn
    let tasks: [TaskItem]
    let onAddTask: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    var onOpenTask: (TaskItem) -> Void = { _ in }
    var onToggleTask: (TaskItem) -> Void = { _ in }
    let draggedTask: TaskItem?
    let targetPlaceholderIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var dragCoordinator: BoardDragCoordinator
    @State private var taskFrames: [UUID: CGRect] = [:]

    init(
        column: BoardColumn,
        tasks: [TaskItem],
        onAddTask: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void,
        onOpenTask: @escaping (TaskItem) -> Void = { _ in },
        onToggleTask: @escaping (TaskItem) -> Void = { _ in },
        draggedTask: TaskItem? = nil,
        targetPlaceholderIndex: Int? = nil,
        dragCoordinator: BoardDragCoordinator
    ) {
        self.column = column
        self.tasks = tasks
        self.onAddTask = onAddTask
        self.onRename = onRename
        self.onArchive = onArchive
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onOpenTask = onOpenTask
        self.onToggleTask = onToggleTask
        self.draggedTask = draggedTask
        self.targetPlaceholderIndex = targetPlaceholderIndex
        _dragCoordinator = ObservedObject(wrappedValue: dragCoordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(column.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x565A52))
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Menu {
                    Button("重命名", action: onRename)
                    if !column.isCompletionColumn {
                        Button("归档列", role: .destructive, action: onArchive)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.quiet)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
            }
            .frame(minHeight: 28)
            .contextMenu {
                Button("重命名", action: onRename)
                if !column.isCompletionColumn {
                    Button("归档列", role: .destructive, action: onArchive)
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if targetPlaceholderIndex == index, let draggedTask {
                            dropPlaceholder(for: draggedTask)
                        }
                        BoardTaskCard(task: task) { onToggleTask(task) }
                            .opacity(BoardDragPresentation.sourceOpacity(isActiveSource: dragCoordinator.taskID == task.id))
                            .animation(
                                placeholderAnimation,
                                value: dragCoordinator.taskID == task.id
                            )
                            .contentShape(Rectangle())
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: BoardTaskFramePreferenceKey.self,
                                        value: [task.id: geometry.frame(in: .global)]
                                    )
                                }
                            }
                            .gesture(dragGesture(for: task))
                            .onTapGesture { onOpenTask(task) }
                    }
                    if targetPlaceholderIndex == tasks.count, let draggedTask {
                        dropPlaceholder(for: draggedTask)
                    }
                }
                .animation(placeholderAnimation, value: targetPlaceholderIndex)
            }

            Button(action: onAddTask) {
                Text("＋ 添加任务")
                    .font(.system(size: 10))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color(hex: 0xD2D3CB))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 248, alignment: .top)
        .background(TaskDesignTokens.canvas.opacity(0.001))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: BoardColumnFramePreferenceKey.self,
                    value: [column.id: geometry.frame(in: .global)]
                )
            }
        }
        .onPreferenceChange(BoardTaskFramePreferenceKey.self) { taskFrames = $0 }
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .strokeBorder(
                    dragCoordinator.taskID != nil && dragCoordinator.targetColumnID == column.id
                        ? TaskDesignTokens.acid
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(
            placeholderAnimation,
            value: dragCoordinator.taskID != nil && dragCoordinator.targetColumnID == column.id
        )
    }

    private var placeholderAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.08)
            : .easeOut(duration: BoardDragPresentation.liftDuration)
    }

    private var placeholderTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
    }

    private func dropPlaceholder(for task: TaskItem) -> some View {
        BoardTaskCard(task: task)
            .opacity(BoardDragPresentation.targetGhostOpacity)
            .overlay(
                RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                    .fill(TaskDesignTokens.acid.opacity(BoardDragPresentation.targetTintOpacity))
            )
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: BoardDropPlaceholderFramePreferenceKey.self,
                        value: [column.id: geometry.frame(in: .global)]
                    )
                }
            }
            .transition(placeholderTransition)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func dragGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                guard let taskFrame = taskFrames[task.id] else { return }
                let grabOffset = CGPoint(
                    x: value.startLocation.x - taskFrame.minX,
                    y: value.startLocation.y - taskFrame.minY
                )
                if dragCoordinator.taskID == nil {
                    withAnimation(placeholderAnimation) {
                        dragCoordinator.begin(
                            taskID: task.id,
                            sourceColumnID: column.id,
                            boardLocation: value.location,
                            sourceFrame: taskFrame,
                            grabOffset: grabOffset
                        )
                    }
                }
                guard dragCoordinator.taskID == task.id else { return }
                onDragChanged(value.location)
            }
            .onEnded { value in
                guard dragCoordinator.taskID == task.id else { return }
                onDragEnded(value.location)
            }
    }
}
