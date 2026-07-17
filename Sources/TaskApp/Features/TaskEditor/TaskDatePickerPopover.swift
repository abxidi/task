import SwiftUI

struct TaskDatePickerPopover: View {
    @Binding private var dueAt: Date?
    @Binding private var reminderAt: Date?
    let onDismiss: () -> Void

    @State private var selectedDay: Date
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var reminderEnabled: Bool
    private let calendar = Calendar.autoupdatingCurrent

    init(
        dueAt: Binding<Date?>,
        reminderAt: Binding<Date?>,
        onDismiss: @escaping () -> Void
    ) {
        _dueAt = dueAt
        _reminderAt = reminderAt
        self.onDismiss = onDismiss
        let initialDate = dueAt.wrappedValue ?? reminderAt.wrappedValue ?? .now
        let calendar = Calendar.autoupdatingCurrent
        _selectedDay = State(initialValue: initialDate)
        _selectedHour = State(initialValue: calendar.component(.hour, from: initialDate))
        _selectedMinute = State(initialValue: calendar.component(.minute, from: initialDate))
        _reminderEnabled = State(initialValue: reminderAt.wrappedValue != nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            quickChoices
                .frame(width: 132)

            Divider()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    DatePicker(
                        "选择任务日期",
                        selection: $selectedDay,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .frame(width: 330, height: 300)
                    .padding(12)

                    Divider()

                    TaskDateTimePicker(hour: $selectedHour, minute: $selectedMinute)
                        .frame(width: 154, height: 324)
                }

                Divider()

                footer
                    .frame(height: 54)
            }
        }
        .frame(width: 644, height: 379)
        .background(TaskDesignTokens.panel)
    }

    private var quickChoices: some View {
        VStack(spacing: 7) {
            ForEach(TaskDateQuickChoice.allCases, id: \.self) { choice in
                Button(choice.title) {
                    setSelection(choice.date(from: .now, calendar: calendar))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TaskDesignTokens.muted)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 5))
                .accessibilityLabel(choice.title)
            }
        }
        .padding(12)
        .background(TaskDesignTokens.canvas)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("此刻") {
                setSelection(.now)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(TaskDesignTokens.muted)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 5))

            Toggle("开启提醒", isOn: $reminderEnabled)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.system(size: 11, weight: .medium))
                .help("在任务日期到达时发送本地通知")

            Spacer(minLength: 0)

            if dueAt != nil {
                Button("清除") {
                    apply(.cleared)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
            }

            Button("确定") {
                apply(.confirmed(date: committedDate, reminderEnabled: reminderEnabled))
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(TaskDesignTokens.acid)
            .padding(.horizontal, 13)
            .frame(minHeight: 31)
            .background(TaskDesignTokens.ink, in: RoundedRectangle(cornerRadius: 5))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 12)
    }

    private var committedDate: Date {
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        components.hour = selectedHour
        components.minute = selectedMinute
        components.second = 0
        return calendar.date(from: components) ?? selectedDay
    }

    private func setSelection(_ date: Date) {
        selectedDay = date
        selectedHour = calendar.component(.hour, from: date)
        selectedMinute = calendar.component(.minute, from: date)
    }

    private func apply(_ commit: TaskDateCommit) {
        dueAt = commit.dueAt
        reminderAt = commit.reminderAt
    }
}
