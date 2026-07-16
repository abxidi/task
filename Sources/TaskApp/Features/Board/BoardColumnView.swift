import Foundation
import SwiftUI
import TaskPersistence

enum BoardDragPresentation {
    static let placeholderOpacity = 0.35

    static func sourceOpacity(isActiveSource: Bool) -> Double {
        isActiveSource ? placeholderOpacity : 1
    }
}

struct BoardColumnFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

final class BoardLegacyDragRegistry {
    static let shared = BoardLegacyDragRegistry()

    private var frames: [UUID: CGRect] = [:]
    private var dropHandlers: [UUID: (UUID) -> Void] = [:]

    func register(columnID: UUID, frame: CGRect, onDropTaskID: @escaping (UUID) -> Void) {
        frames[columnID] = frame
        dropHandlers[columnID] = onDropTaskID
    }

    func columnID(at boardLocation: CGPoint) -> UUID? {
        frames.first { $0.value.contains(boardLocation) }?.key
    }

    func move(_ taskID: UUID, to columnID: UUID) {
        dropHandlers[columnID]?(taskID)
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
    @ObservedObject var dragCoordinator: BoardDragCoordinator
    private let legacyDragRegistry: BoardLegacyDragRegistry?
    private let legacyOnDropTaskID: ((UUID) -> Void)?

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
        dragCoordinator: BoardDragCoordinator,
        legacyDragRegistry: BoardLegacyDragRegistry? = nil,
        legacyOnDropTaskID: ((UUID) -> Void)? = nil
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
        _dragCoordinator = ObservedObject(wrappedValue: dragCoordinator)
        self.legacyDragRegistry = legacyDragRegistry
        self.legacyOnDropTaskID = legacyOnDropTaskID
    }

    init(
        column: BoardColumn,
        tasks: [TaskItem],
        onDropTaskID: @escaping (UUID) -> Void,
        onAddTask: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onOpenTask: @escaping (TaskItem) -> Void = { _ in },
        onToggleTask: @escaping (TaskItem) -> Void = { _ in },
        draggingTaskID: Binding<UUID?>
    ) {
        let coordinator = BoardDragCoordinator()
        let registry = BoardLegacyDragRegistry.shared
        self.init(
            column: column,
            tasks: tasks,
            onAddTask: onAddTask,
            onRename: onRename,
            onArchive: onArchive,
            onDragChanged: { boardLocation in
                guard let targetColumnID = registry.columnID(at: boardLocation) else { return }
                coordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
                draggingTaskID.wrappedValue = coordinator.taskID
            },
            onDragEnded: { boardLocation in
                guard let targetColumnID = registry.columnID(at: boardLocation) else {
                    coordinator.cancel()
                    draggingTaskID.wrappedValue = nil
                    return
                }
                coordinator.update(boardLocation: boardLocation, targetColumnID: targetColumnID)
                if let dragMove = coordinator.finish() {
                    registry.move(dragMove.taskID, to: dragMove.targetColumnID)
                }
                draggingTaskID.wrappedValue = nil
            },
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
            dragCoordinator: coordinator,
            legacyDragRegistry: registry,
            legacyOnDropTaskID: onDropTaskID
        )
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
                    ForEach(tasks) { task in
                        BoardTaskCard(task: task) { onToggleTask(task) }
                            .opacity(BoardDragPresentation.sourceOpacity(isActiveSource: dragCoordinator.taskID == task.id))
                            .contentShape(Rectangle())
                            .gesture(dragGesture(for: task))
                            .onTapGesture { onOpenTask(task) }
                    }
                }
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
        .onPreferenceChange(BoardColumnFramePreferenceKey.self) { frames in
            guard
                let legacyDragRegistry,
                let legacyOnDropTaskID,
                let frame = frames[column.id]
            else {
                return
            }
            legacyDragRegistry.register(columnID: column.id, frame: frame, onDropTaskID: legacyOnDropTaskID)
        }
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(
                    dragCoordinator.taskID != nil && dragCoordinator.targetColumnID == column.id
                        ? TaskDesignTokens.acid
                        : Color.clear,
                    lineWidth: 2
                )
        )
    }

    private func dragGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                if dragCoordinator.taskID == nil {
                    dragCoordinator.begin(
                        taskID: task.id,
                        sourceColumnID: column.id,
                        boardLocation: value.location
                    )
                }
                onDragChanged(value.location)
            }
            .onEnded { value in
                onDragEnded(value.location)
            }
    }
}
