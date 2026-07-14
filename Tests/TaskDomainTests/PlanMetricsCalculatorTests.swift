import Foundation
import XCTest
@testable import TaskDomain

final class PlanMetricsCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testCompletionRateOnlyUsesTasksDueInRange() {
        let range = now...now.addingTimeInterval(7 * 86_400)
        let tasks = [
            task("done", due: now.addingTimeInterval(100), completed: true, minutes: 60),
            task("open", due: now.addingTimeInterval(200), completed: false, minutes: 30),
            task("no-date", due: nil, completed: true, minutes: 30),
        ]
        let result = PlanMetricsCalculator.calculate(tasks: tasks, range: range, capacityMinutes: 600, now: now)
        XCTAssertEqual(result.completionRate, 0.5)
    }

    func testLoadSeparatesMissingEstimates() {
        let range = now...now.addingTimeInterval(7 * 86_400)
        let tasks = [
            task("estimated", due: now.addingTimeInterval(100), completed: false, minutes: 90),
            task("missing", due: now.addingTimeInterval(200), completed: false, minutes: nil),
        ]
        let result = PlanMetricsCalculator.calculate(tasks: tasks, range: range, capacityMinutes: 600, now: now)
        XCTAssertEqual(result.plannedMinutes, 90)
        XCTAssertEqual(result.missingEstimateCount, 1)
    }

    func testHealthDeductionsAreCappedAndExplained() {
        let range = now...now.addingTimeInterval(7 * 86_400)
        var tasks = (0..<8).map { index in
            task("late-\(index)", due: now.addingTimeInterval(-100), completed: false, minutes: 60)
        }
        tasks += (0..<6).map { index in
            MetricsTask(id: "act-\(index)", coordinate: .init(uncheckedUrgency: 3, importance: 3), dueAt: nil, estimatedMinutes: nil, isCompleted: false, completedAt: nil)
        }
        tasks += (0..<12).map { index in
            MetricsTask(id: "zero-\(index)", coordinate: .init(uncheckedUrgency: 0, importance: 0), dueAt: nil, estimatedMinutes: nil, isCompleted: false, completedAt: nil)
        }
        tasks += (0..<8).map { index in
            task("load-\(index)", due: now.addingTimeInterval(Double(index + 1) * 100), completed: false, minutes: 60)
        }
        let result = PlanMetricsCalculator.calculate(tasks: tasks, range: range, capacityMinutes: 120, now: now)
        XCTAssertEqual(result.healthScore, 0)
        XCTAssertEqual(result.deductions.map(\.points), [30, 20, 30, 20])
    }

    private func task(_ id: String, due: Date?, completed: Bool, minutes: Int?) -> MetricsTask<String> {
        MetricsTask(
            id: id,
            coordinate: .init(uncheckedUrgency: 1, importance: 1),
            dueAt: due,
            estimatedMinutes: minutes,
            isCompleted: completed,
            completedAt: completed ? now : nil
        )
    }
}
