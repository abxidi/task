import SwiftUI

enum TaskDateCalendarGrid {
    static func days(for month: Date, calendar: Calendar) -> [Date] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) else {
            return []
        }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

struct TaskDateCalendarPicker: View {
    @Binding private var selectedDay: Date
    private let range: ClosedRange<Date>
    private let calendar: Calendar
    @State private var displayedMonth: Date

    init(
        selectedDay: Binding<Date>,
        range: ClosedRange<Date>,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        _selectedDay = selectedDay
        self.range = range
        self.calendar = calendar
        let components = calendar.dateComponents([.year, .month], from: selectedDay.wrappedValue)
        _displayedMonth = State(initialValue: calendar.date(from: components) ?? selectedDay.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days, id: \.self) { day in
                    dayButton(day)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 24), spacing: 0), count: 7)
    }

    private var days: [Date] {
        TaskDateCalendarGrid.days(for: displayedMonth, calendar: calendar)
    }

    private var monthHeader: some View {
        HStack(spacing: 6) {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("上个月")
            .accessibilityLabel("上个月")

            Spacer(minLength: 0)

            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(TaskDesignTokens.ink)

            Spacer(minLength: 0)

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("下个月")
            .accessibilityLabel("下个月")
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .frame(maxWidth: .infinity, minHeight: 22)
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { offset in
            symbols[(calendar.firstWeekday - 1 + offset) % symbols.count]
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let belongsToMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let selectable = isSelectable(day)
        return Button {
            selectedDay = day
        } label: {
            Text(String(calendar.component(.day, from: day)))
                .font(.system(size: 12, weight: selected ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(dayForeground(belongsToMonth: belongsToMonth, selected: selected, selectable: selectable))
                .frame(maxWidth: .infinity, minHeight: 27)
                .background(selected ? TaskDesignTokens.acid : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityLabel(day.formatted(date: .long, time: .omitted))
        .accessibilityValue(selected ? "已选中" : "")
    }

    private func dayForeground(belongsToMonth: Bool, selected: Bool, selectable: Bool) -> Color {
        if selected { return TaskDesignTokens.ink }
        if !selectable || !belongsToMonth { return TaskDesignTokens.quiet.opacity(0.45) }
        return TaskDesignTokens.muted
    }

    private func isSelectable(_ day: Date) -> Bool {
        let normalized = calendar.startOfDay(for: day)
        return normalized >= calendar.startOfDay(for: range.lowerBound)
            && normalized <= calendar.startOfDay(for: range.upperBound)
    }

    private func changeMonth(by offset: Int) {
        guard let month = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = month
    }
}

enum TaskDatePopoverLayout {
    static let startSize = CGSize(width: 372, height: 296)
    static let startCalendarWidth: CGFloat = 268
    static let startTimeWidth: CGFloat = 103
    static let startContentHeight: CGFloat = 253
    static let startFooterHeight: CGFloat = 42
    static let endCalendarWidth: CGFloat = 330
    static let endTimeWidth: CGFloat = 154
    static let endContentHeight: CGFloat = 332
    static let endFooterHeight: CGFloat = 54

    static func contentSize(for mode: TaskDatePickerMode) -> CGSize {
        switch mode {
        case .start: startSize
        case .end: CGSize(width: 512, height: 387)
        }
    }

    static func calendarWidth(for mode: TaskDatePickerMode) -> CGFloat {
        switch mode {
        case .start: startCalendarWidth
        case .end: endCalendarWidth
        }
    }

    static func timeWidth(for mode: TaskDatePickerMode) -> CGFloat {
        switch mode {
        case .start: startTimeWidth
        case .end: endTimeWidth
        }
    }

    static func contentHeight(for mode: TaskDatePickerMode) -> CGFloat {
        switch mode {
        case .start: startContentHeight
        case .end: endContentHeight
        }
    }

    static func footerHeight(for mode: TaskDatePickerMode) -> CGFloat {
        switch mode {
        case .start: startFooterHeight
        case .end: endFooterHeight
        }
    }
}
