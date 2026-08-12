import SwiftUI

enum TaskDatePopoverPresentation {
    static let preferredArrowEdge: Edge = .top
}

struct TaskDateEditorRow: View {
    @Binding var startAt: Date?
    @Binding var dueAt: Date?
    @Binding var reminderAt: Date?
    @State private var isStartPickerPresented = false
    @State private var isEndPickerPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Text("时间")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TaskDesignTokens.muted)

            dateButton(
                title: "启动时间",
                date: startAt,
                isPresented: $isStartPickerPresented
            )
            .popover(isPresented: $isStartPickerPresented, arrowEdge: TaskDatePopoverPresentation.preferredArrowEdge) {
                TaskDatePickerPopover(
                    mode: .start,
                    startAt: $startAt,
                    dueAt: $dueAt,
                    reminderAt: $reminderAt,
                    onDismiss: { isStartPickerPresented = false }
                )
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
                .accessibilityHidden(true)

            dateButton(
                title: "结束时间",
                date: dueAt,
                isPresented: $isEndPickerPresented,
                showsReminder: reminderAt != nil
            )
            .popover(isPresented: $isEndPickerPresented, arrowEdge: TaskDatePopoverPresentation.preferredArrowEdge) {
                TaskDatePickerPopover(
                    mode: .end,
                    startAt: $startAt,
                    dueAt: $dueAt,
                    reminderAt: $reminderAt,
                    onDismiss: { isEndPickerPresented = false }
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func dateButton(
        title: String,
        date: Date?,
        isPresented: Binding<Bool>,
        showsReminder: Bool = false
    ) -> some View {
        Button {
            isPresented.wrappedValue = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: date == nil ? "calendar.badge.plus" : "calendar")
                    .font(.system(size: 10, weight: .medium))
                Text(date.map(Self.dateLabel) ?? title)
                    .lineLimit(1)
                if showsReminder {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.success)
                }
            }
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(date == nil ? TaskDesignTokens.quiet : TaskDesignTokens.muted)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("设置\(title)")
    }

    private static func dateLabel(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
    }
}
