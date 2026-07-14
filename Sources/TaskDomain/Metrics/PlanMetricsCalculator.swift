import Foundation

public enum PlanMetricsCalculator {
    public static func calculate<ID: Hashable & Sendable>(
        tasks: [MetricsTask<ID>],
        range: ClosedRange<Date>,
        capacityMinutes: Int,
        now: Date
    ) -> PlanMetrics {
        let dueInRange = tasks.filter { task in
            guard let due = task.dueAt else { return false }
            return range.contains(due)
        }
        let completedCount = dueInRange.filter(\.isCompleted).count
        let completionRate = dueInRange.isEmpty ? nil : Double(completedCount) / Double(dueInRange.count)
        let unfinishedDue = dueInRange.filter { !$0.isCompleted }
        let plannedMinutes = unfinishedDue.compactMap(\.estimatedMinutes).reduce(0, +)
        let missingEstimateCount = unfinishedDue.filter { $0.estimatedMinutes == nil }.count
        let highImportanceCount = tasks.filter { !$0.isCompleted && $0.coordinate.importance >= 3 }.count

        let overdueCount = tasks.filter { !$0.isCompleted && ($0.dueAt ?? .distantFuture) < now }.count
        let actNowWithoutDateCount = tasks.filter { !$0.isCompleted && $0.coordinate.quadrant == .actNow && $0.dueAt == nil }.count
        let overloadHours = Int(ceil(Double(max(0, plannedMinutes - capacityMinutes)) / 60))
        let undecidedCount = tasks.filter { !$0.isCompleted && $0.coordinate.urgency == 0 && $0.coordinate.importance == 0 }.count

        let deductions = [
            HealthDeduction(reason: .overdue, points: min(30, overdueCount * 6), itemCount: overdueCount),
            HealthDeduction(reason: .actNowWithoutDate, points: min(20, actNowWithoutDateCount * 4), itemCount: actNowWithoutDateCount),
            HealthDeduction(reason: .overCapacity, points: min(30, overloadHours * 5), itemCount: overloadHours),
            HealthDeduction(reason: .undecided, points: min(20, undecidedCount * 2), itemCount: undecidedCount),
        ]

        return PlanMetrics(
            completionRate: completionRate,
            highImportanceCount: highImportanceCount,
            plannedMinutes: plannedMinutes,
            missingEstimateCount: missingEstimateCount,
            healthScore: max(0, 100 - deductions.reduce(0) { $0 + $1.points }),
            deductions: deductions
        )
    }

    public static func completionTrend<ID: Hashable & Sendable>(
        tasks: [MetricsTask<ID>],
        range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> [(day: Date, count: Int)] {
        var buckets: [Date: Int] = [:]
        var day = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        while day <= end {
            buckets[day] = 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for task in tasks {
            guard task.isCompleted, let completedAt = task.completedAt else { continue }
            let key = calendar.startOfDay(for: completedAt)
            if buckets.keys.contains(key) {
                buckets[key, default: 0] += 1
            }
        }
        return buckets.keys.sorted().map { (day: $0, count: buckets[$0] ?? 0) }
    }

    public static func quadrantDistribution<ID: Hashable & Sendable>(
        tasks: [MetricsTask<ID>]
    ) -> [PriorityQuadrant: Int] {
        var result: [PriorityQuadrant: Int] = Dictionary(uniqueKeysWithValues: PriorityQuadrant.allCases.map { ($0, 0) })
        for task in tasks where !task.isCompleted {
            result[task.coordinate.quadrant, default: 0] += 1
        }
        return result
    }
}
