import SwiftUI
import TaskDomain
import TaskPersistence

struct BoardTaskCard: View {
    let task: TaskItem
    var onToggleCompletion: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onToggleCompletion?()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(task.isCompleted ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                }
                .buttonStyle(.plain)
                .disabled(onToggleCompletion == nil)
                .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")

                Text(task.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x3D413A))
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)
                    .padding(.trailing, TaskCardLayout.titleTrailingReservation)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 5) {
                if let dueAt = task.dueAt {
                    metaChip(dueAt.formatted(date: .abbreviated, time: .omitted))
                }
                if let minutes = task.estimatedMinutes {
                    metaChip("\(minutes) 分")
                }
                if task.dueAt == nil && task.estimatedMinutes == nil {
                    metaChip("无日期")
                }
            }
        }
        .padding(10)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            PriorityMarkerView(
                coordinate: .init(uncheckedUrgency: task.urgency, importance: task.importance),
                title: task.title,
                isSelected: false,
                isCompact: true
            )
            .padding(TaskCardLayout.priorityBadgeInset)
        }
        .overlay(alignment: TaskCardLayout.deletionActionAlignment) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TaskDesignTokens.quiet)
                .help("删除任务")
                .accessibilityLabel("删除任务")
                .padding(6)
            }
        }
        .opacity(task.isCompleted ? 0.56 : 1)
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8))
            .foregroundStyle(TaskDesignTokens.quiet)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Color(hex: 0xEFEFE9), in: RoundedRectangle(cornerRadius: 3))
    }
}

enum TaskCardLayout {
    static let priorityBadgeInset: CGFloat = 10
    static let titleTrailingReservation: CGFloat = 32
    static let deletionActionAlignment: Alignment = .bottomTrailing
}
