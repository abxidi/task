import SwiftUI

struct TaskDateEditorRow: View {
    @Binding var dueAt: Date?
    @Binding var reminderAt: Date?
    @State private var isPickerPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Text("任务日期")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TaskDesignTokens.muted)

            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 7) {
                    Text(dueAt.map(Self.dateLabel) ?? "设置日期")
                        .lineLimit(1)
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                    if reminderAt != nil {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(TaskDesignTokens.success)
                    }
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(dueAt == nil ? TaskDesignTokens.quiet : TaskDesignTokens.muted)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("设置任务日期和提醒")
            .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
                TaskDatePickerPopover(
                    dueAt: $dueAt,
                    reminderAt: $reminderAt,
                    onDismiss: { isPickerPresented = false }
                )
            }

            if dueAt != nil {
                Button {
                    apply(.cleared)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.quiet)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("清除任务日期")
                .accessibilityLabel("清除任务日期")
            }

            Spacer(minLength: 0)
        }
    }

    private func apply(_ commit: TaskDateCommit) {
        dueAt = commit.dueAt
        reminderAt = commit.reminderAt
    }

    private static func dateLabel(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
    }
}
