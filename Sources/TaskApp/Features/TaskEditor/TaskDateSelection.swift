import Foundation

enum TaskDateQuickChoice: CaseIterable, Hashable {
    case twoHours
    case eightHours
    case oneDay
    case twoDays
    case oneWeek
    case twoWeeks
    case oneMonth
    case twoMonths
    case sixMonths

    var title: String {
        switch self {
        case .twoHours: "两小时后"
        case .eightHours: "八小时后"
        case .oneDay: "一天后"
        case .twoDays: "两天后"
        case .oneWeek: "一周后"
        case .twoWeeks: "两周后"
        case .oneMonth: "一月后"
        case .twoMonths: "两月后"
        case .sixMonths: "半年后"
        }
    }

    func date(from base: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let component: Calendar.Component
        let value: Int
        switch self {
        case .twoHours:
            component = .hour
            value = 2
        case .eightHours:
            component = .hour
            value = 8
        case .oneDay:
            component = .day
            value = 1
        case .twoDays:
            component = .day
            value = 2
        case .oneWeek:
            component = .weekOfYear
            value = 1
        case .twoWeeks:
            component = .weekOfYear
            value = 2
        case .oneMonth:
            component = .month
            value = 1
        case .twoMonths:
            component = .month
            value = 2
        case .sixMonths:
            component = .month
            value = 6
        }
        return calendar.date(byAdding: component, value: value, to: base) ?? base
    }
}

struct TaskDateCommit: Equatable {
    let dueAt: Date?
    let reminderAt: Date?

    static func confirmed(date: Date, reminderEnabled: Bool) -> Self {
        Self(dueAt: date, reminderAt: reminderEnabled ? date : nil)
    }

    static let cleared = Self(dueAt: nil, reminderAt: nil)
}
