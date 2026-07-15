import Foundation
import SwiftUI
import TaskPersistence

enum BoardDragPresentation {
    static let hiddenSourceOpacity = 0.001

    static func sourceOpacity(for taskID: UUID, draggingTaskID: UUID?) -> Double {
        taskID == draggingTaskID ? hiddenSourceOpacity : 1
    }
}

struct BoardColumnView: View {
    let column: BoardColumn
    let tasks: [TaskItem]
    let onDropTaskID: (UUID) -> Void
    let onAddTask: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void
    var onOpenTask: (TaskItem) -> Void = { _ in }
    var onToggleTask: (TaskItem) -> Void = { _ in }
    @Binding var draggingTaskID: UUID?
    @State private var isTargeted = false

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
                            .opacity(BoardDragPresentation.sourceOpacity(for: task.id, draggingTaskID: draggingTaskID))
                            .onDrag {
                                draggingTaskID = task.id
                                return NSItemProvider(object: task.id.uuidString as NSString)
                            } preview: {
                                BoardTaskCard(task: task)
                                    .frame(width: 248, alignment: .leading)
                                    .compositingGroup()
                            }
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
        .frame(minWidth: 220, idealWidth: 248, maxWidth: 280, alignment: .top)
        .background(TaskDesignTokens.canvas.opacity(0.001))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(isTargeted ? TaskDesignTokens.acid : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self, action: { values, _ in
            guard let raw = values.first, let id = UUID(uuidString: raw) else {
                draggingTaskID = nil
                return false
            }
            onDropTaskID(id)
            draggingTaskID = nil
            return true
        }, isTargeted: { targeted in
            withTransaction(Transaction(animation: nil)) {
                isTargeted = targeted
            }
        })
    }
}
