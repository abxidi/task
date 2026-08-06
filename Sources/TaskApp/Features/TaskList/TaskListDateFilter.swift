import Foundation

enum TaskListDateFilter {
    static func matches(
        dueAt: Date?,
        in scope: TaskListScope,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let dueAt else { return false }

        let component: Calendar.Component
        switch scope {
        case .today:
            component = .day
        case .thisWeek:
            component = .weekOfYear
        case .all, .completed:
            return true
        }

        guard let interval = calendar.dateInterval(of: component, for: now) else {
            return false
        }
        return dueAt >= interval.start && dueAt < interval.end
    }
}
