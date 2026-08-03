import SwiftUI

enum TaskDatePickerMode {
    case start
    case end

    var title: String {
        switch self {
        case .start: "启动时间"
        case .end: "结束时间"
        }
    }
}

struct TaskDatePickerPopover: View {
    let mode: TaskDatePickerMode
    @Binding private var startAt: Date?
    @Binding private var dueAt: Date?
    @Binding private var reminderAt: Date?
    let onDismiss: () -> Void

    @State private var selectedDay: Date
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var reminderEnabled: Bool
    private let calendar = Calendar.autoupdatingCurrent

    init(
        mode: TaskDatePickerMode,
        startAt: Binding<Date?>,
        dueAt: Binding<Date?>,
        reminderAt: Binding<Date?>,
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        _startAt = startAt
        _dueAt = dueAt
        _reminderAt = reminderAt
        self.onDismiss = onDismiss
        let initialDate: Date
        switch mode {
        case .start:
            initialDate = startAt.wrappedValue ?? .now
        case .end:
            initialDate = dueAt.wrappedValue ?? reminderAt.wrappedValue ?? .now
        }
        let calendar = Calendar.autoupdatingCurrent
        _selectedDay = State(initialValue: initialDate)
        _selectedHour = State(initialValue: calendar.component(.hour, from: initialDate))
        _selectedMinute = State(initialValue: calendar.component(.minute, from: initialDate))
        _reminderEnabled = State(initialValue: reminderAt.wrappedValue != nil)
    }

    var body: some View {
        Group {
            if mode == .end {
                HStack(spacing: 0) {
                    quickChoices
                        .frame(width: 132)
                    Divider()
                    calendarAndTime
                }
            } else {
                calendarAndTime
            }
        }
        .background(TaskDesignTokens.panel)
    }

    private var calendarAndTime: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TaskDateCalendarPicker(
                    selectedDay: $selectedDay,
                    range: dateRange
                )
                .frame(
                    width: TaskDatePopoverLayout.calendarWidth(for: mode),
                    height: TaskDatePopoverLayout.contentHeight(for: mode)
                )

                Divider()

                TaskDateTimePicker(hour: $selectedHour, minute: $selectedMinute)
                    .frame(
                        width: TaskDatePopoverLayout.timeWidth(for: mode),
                        height: TaskDatePopoverLayout.contentHeight(for: mode)
                    )
            }

            Divider()

            footer
                .frame(height: TaskDatePopoverLayout.footerHeight(for: mode))
        }
        .frame(
            width: TaskDatePopoverLayout.contentSize(for: mode).width,
            height: TaskDatePopoverLayout.contentSize(for: mode).height
        )
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

            if mode == .end {
                Toggle("结束时提醒", isOn: $reminderEnabled)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .font(.system(size: 11, weight: .medium))
                    .help("在结束时间到达时发送本地通知")
            }

            Spacer(minLength: 0)

            if selectedValue != nil {
                Button("清除") {
                    clearSelection()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
            }

            Button("确定") {
                applyCommittedDate()
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(TaskDesignTokens.acid)
            .padding(.horizontal, 13)
            .frame(minHeight: 31)
            .background(TaskDesignTokens.ink, in: RoundedRectangle(cornerRadius: 5))
            .keyboardShortcut(.defaultAction)
            .disabled(!isCommittedDateValid)
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

    private var dateRange: ClosedRange<Date> {
        switch mode {
        case .start:
            return .distantPast...(dueAt ?? .distantFuture)
        case .end:
            return (startAt ?? .distantPast)...Date.distantFuture
        }
    }

    private var selectedValue: Date? {
        switch mode {
        case .start: startAt
        case .end: dueAt
        }
    }

    private var isCommittedDateValid: Bool {
        switch mode {
        case .start:
            return dueAt.map { committedDate <= $0 } ?? true
        case .end:
            return startAt.map { committedDate >= $0 } ?? true
        }
    }

    private func applyCommittedDate() {
        switch mode {
        case .start:
            startAt = committedDate
        case .end:
            let commit = TaskDateRangeCommit.confirmed(
                startAt: startAt,
                endAt: committedDate,
                isEndReminderEnabled: reminderEnabled
            )
            startAt = commit.startAt
            dueAt = commit.dueAt
            reminderAt = commit.reminderAt
        }
    }

    private func clearSelection() {
        switch mode {
        case .start:
            startAt = nil
        case .end:
            dueAt = nil
            reminderAt = nil
        }
    }
}
