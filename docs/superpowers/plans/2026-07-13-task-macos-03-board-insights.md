# Task macOS 03 Board and Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可拖拽的项目看板、完成状态一致性、真实趋势图和可解释的计划健康度。

**Architecture:** 指标计算和看板状态转换是纯领域服务；SwiftData service 负责事务和关系更新；SwiftUI 看板与 Swift Charts 只渲染结果。任何健康度分数都同时返回扣分明细。

**Tech Stack:** SwiftData、SwiftUI、Swift Charts、TaskDomain、XCTest、macOS 14+

---

## 前置条件

计划 01 和 02 完成门必须通过。当前应用应能创建、编辑、完成和设置优先级。

## 文件结构

```text
Sources/TaskDomain/Metrics/MetricsTask.swift
Sources/TaskDomain/Metrics/PlanMetrics.swift
Sources/TaskDomain/Metrics/PlanMetricsCalculator.swift
Sources/TaskPersistence/BoardWorkflowService.swift
Sources/TaskPersistence/ProjectRepository.swift
Sources/TaskApp/Features/Board/ProjectBoardScreen.swift
Sources/TaskApp/Features/Board/BoardColumnView.swift
Sources/TaskApp/Features/Board/BoardTaskCard.swift
Sources/TaskApp/Features/Board/MetricsStrip.swift
Sources/TaskApp/Features/Board/CompletionTrendChart.swift
Sources/TaskApp/Features/Board/QuadrantDistributionChart.swift
Sources/TaskApp/Features/Insights/InsightsScreen.swift
Tests/TaskDomainTests/PlanMetricsCalculatorTests.swift
Tests/TaskPersistenceTests/BoardWorkflowServiceTests.swift
```

### Task 1: Implement metrics calculation with TDD

**Files:**

- Create: `Tests/TaskDomainTests/PlanMetricsCalculatorTests.swift`
- Create: `Sources/TaskDomain/Metrics/MetricsTask.swift`
- Create: `Sources/TaskDomain/Metrics/PlanMetrics.swift`
- Create: `Sources/TaskDomain/Metrics/PlanMetricsCalculator.swift`

- [ ] **Step 1: Write failing metric tests**

```swift
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

    private func task(_ id: String, due: Date?, completed: Bool, minutes: Int?) -> MetricsTask {
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
```

- [ ] **Step 2: Verify failure**

```bash
swift test --filter PlanMetricsCalculatorTests
```

Expected: FAIL because metrics types do not exist.

- [ ] **Step 3: Add immutable metric DTOs**

```swift
// Sources/TaskDomain/Metrics/MetricsTask.swift
import Foundation

public struct MetricsTask<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let coordinate: PriorityCoordinate
    public let dueAt: Date?
    public let estimatedMinutes: Int?
    public let isCompleted: Bool
    public let completedAt: Date?

    public init(id: ID, coordinate: PriorityCoordinate, dueAt: Date?, estimatedMinutes: Int?, isCompleted: Bool, completedAt: Date?) {
        self.id = id
        self.coordinate = coordinate
        self.dueAt = dueAt
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
```

```swift
// Sources/TaskDomain/Metrics/PlanMetrics.swift
public enum HealthDeductionReason: String, Equatable, Sendable {
    case overdue
    case actNowWithoutDate
    case overCapacity
    case undecided
}

public struct HealthDeduction: Equatable, Sendable {
    public let reason: HealthDeductionReason
    public let points: Int
    public let itemCount: Int
}

public struct PlanMetrics: Equatable, Sendable {
    public let completionRate: Double?
    public let highImportanceCount: Int
    public let plannedMinutes: Int
    public let missingEstimateCount: Int
    public let healthScore: Int
    public let deductions: [HealthDeduction]
}
```

- [ ] **Step 4: Implement the exact approved formula**

```swift
// Sources/TaskDomain/Metrics/PlanMetricsCalculator.swift
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
}
```

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter PlanMetricsCalculatorTests
git add Sources/TaskDomain/Metrics Tests/TaskDomainTests/PlanMetricsCalculatorTests.swift
git commit -m "feat: add explainable plan metrics"
```

Expected: tests pass and deductions retain all four reasons, including zero-point entries for stable UI order.

### Task 2: Enforce board completion invariants

**Files:**

- Create: `Tests/TaskPersistenceTests/BoardWorkflowServiceTests.swift`
- Create: `Sources/TaskPersistence/BoardWorkflowService.swift`
- Create: `Sources/TaskPersistence/ProjectRepository.swift`

- [ ] **Step 1: Write failing workflow tests**

```swift
import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class BoardWorkflowServiceTests: XCTestCase {
    func testNewProjectHasExactlyOneCompletionColumn() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let project = try repository.createProject(name: "Launch", colorHex: "#F07446")
        XCTAssertEqual(project.boardColumns.count, 4)
        XCTAssertEqual(project.boardColumns.filter(\.isCompletionColumn).count, 1)
    }

    func testMoveIntoAndOutOfCompletionColumnMaintainsState() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = ProjectRepository(context: container.mainContext)
        let project = try repository.createProject(name: "Launch", colorHex: "#F07446")
        let todo = project.boardColumns.sorted { $0.order < $1.order }.first!
        let done = project.boardColumns.first(where: \.isCompletionColumn)!
        let task = TaskItem(title: "Plan")
        task.project = project
        task.boardColumn = todo
        container.mainContext.insert(task)
        let service = BoardWorkflowService(context: container.mainContext)

        try service.move(task, to: done, now: Date(timeIntervalSince1970: 500))
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.completedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(task.previousBoardColumnID, todo.id)

        try service.move(task, to: todo, now: Date(timeIntervalSince1970: 600))
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
    }
}
```

- [ ] **Step 2: Verify failure**

```bash
swift test --filter BoardWorkflowServiceTests
```

Expected: FAIL because repositories/services do not exist.

- [ ] **Step 3: Implement default project columns**

```swift
import SwiftData

@MainActor
public final class ProjectRepository {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func createProject(name: String, colorHex: String) throws -> Project {
        let project = Project(name: name, colorHex: colorHex)
        let columns = [
            BoardColumn(name: "待规划", order: 0),
            BoardColumn(name: "本周计划", order: 1),
            BoardColumn(name: "进行中", order: 2),
            BoardColumn(name: "已完成", order: 3, isCompletionColumn: true),
        ]
        columns.forEach { $0.project = project }
        project.boardColumns = columns
        context.insert(project)
        try context.save()
        return project
    }
}
```

- [ ] **Step 4: Implement transactional moves**

```swift
import Foundation
import SwiftData

@MainActor
public final class BoardWorkflowService {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func move(_ task: TaskItem, to column: BoardColumn, now: Date = .now) throws {
        guard let projectID = task.project?.id, projectID == column.project?.id else {
            throw BoardWorkflowError.projectMismatch
        }
        if column.isCompletionColumn {
            if let current = task.boardColumn, !current.isCompletionColumn {
                task.previousBoardColumnID = current.id
            }
            task.isCompleted = true
            task.completedAt = now
        } else {
            task.isCompleted = false
            task.completedAt = nil
        }
        task.boardColumn = column
        task.updatedAt = now
        try context.save()
    }
}

public enum BoardWorkflowError: Error, Equatable {
    case projectMismatch
    case missingCompletionColumn
}
```

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter BoardWorkflowServiceTests
git add Sources/TaskPersistence Tests/TaskPersistenceTests/BoardWorkflowServiceTests.swift
git commit -m "feat: enforce project board completion state"
```

### Task 3: Build the board UI and drag/drop

**Files:**

- Create: `Sources/TaskApp/Features/Board/BoardTaskCard.swift`
- Create: `Sources/TaskApp/Features/Board/BoardColumnView.swift`
- Create: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`
- Modify: `Sources/TaskApp/App/TaskAppShell.swift`

- [ ] **Step 1: Implement the shared task card**

`BoardTaskCard` must reuse `PriorityMarkerView`, show a two-line title, then date and estimate metadata. It receives a `TaskItem` and has no repository dependency.

- [ ] **Step 2: Implement a stable column surface**

```swift
struct BoardColumnView: View {
    let column: BoardColumn
    let tasks: [TaskItem]
    let onDropTaskID: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(column.name).font(.headline); Spacer(); Text("\(tasks.count)").foregroundStyle(.secondary) }
            ForEach(tasks) { task in
                BoardTaskCard(task: task)
                    .draggable(task.id.uuidString)
            }
            Button("添加任务", systemImage: "plus") {}
                .buttonStyle(.plain)
        }
        .frame(minWidth: 220, idealWidth: 248, maxWidth: 280, alignment: .top)
        .dropDestination(for: String.self) { values, _ in
            guard let raw = values.first, let id = UUID(uuidString: raw) else { return false }
            onDropTaskID(id)
            return true
        }
    }
}
```

- [ ] **Step 3: Fetch once and group in memory**

`ProjectBoardScreen` queries columns ordered by `order` and project tasks once. Build `[UUID: [TaskItem]]` with `Dictionary(grouping:by:)`; do not issue one query per column.

- [ ] **Step 4: Wire drops through BoardWorkflowService**

Resolve the task ID from the fetched task array, call `service.move(task,to:)`, and present an alert on failure. Keep the task in its previous column if save fails.

- [ ] **Step 5: Add column rename/reorder commands**

Use context menus for rename/archive and `onMove` in the column-management sheet. Prevent archiving the completion column and prevent creating a second completion column.

- [ ] **Step 6: Verify and commit**

```bash
swift build
swift run TaskApp
```

Manual checks: create a project; verify four default columns; drag a task into and out of completion; relaunch and verify state.

```bash
git add Sources/TaskApp/Features/Board Sources/TaskApp/App/TaskAppShell.swift
git commit -m "feat: add draggable project board"
```

### Task 4: Add metrics strip and charts

**Files:**

- Create: `Sources/TaskApp/Features/Board/MetricsStrip.swift`
- Create: `Sources/TaskApp/Features/Board/CompletionTrendChart.swift`
- Create: `Sources/TaskApp/Features/Board/QuadrantDistributionChart.swift`
- Modify: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`

- [ ] **Step 1: Add a single segmented metrics strip**

Use one rounded container with dividers, not four floating cards. Each metric gets an accessibility label. If completion rate is `nil`, display `—`, not `0%`.

- [ ] **Step 2: Add health deduction disclosure**

Clicking health score opens a popover listing every non-zero `HealthDeduction` with reason, item count, and points. The sum shown in the popover must equal `100 - healthScore`.

- [ ] **Step 3: Add Swift Charts trend**

```swift
import Charts
import SwiftUI

struct CompletionTrendChart: View {
    let points: [CompletionPoint]
    var body: some View {
        Chart(points) { point in
            BarMark(x: .value("日期", point.day), y: .value("完成", point.count))
                .foregroundStyle(TaskDesignTokens.acid)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .accessibilityLabel("完成趋势")
    }
}

struct CompletionPoint: Identifiable {
    let day: Date
    let count: Int
    var id: Date { day }
}
```

- [ ] **Step 4: Add quadrant distribution**

Group tasks by `PriorityQuadrant`, including `.undecided`. Use a donut chart plus text legend. Do not use the seven urgency colors as data-series colors; use the semantic quadrant palette from the UI spec.

- [ ] **Step 5: Verify empty states**

With no due dates: completion rate is `—`, load is `0h` plus missing estimate count if applicable, charts show a simple empty state, and no synthetic bars appear.

- [ ] **Step 6: Commit**

```bash
git add Sources/TaskApp/Features/Board
git commit -m "feat: add project metrics and charts"
```

### Task 5: Add the insights screen

**Files:**

- Create: `Sources/TaskApp/Features/Insights/InsightsScreen.swift`
- Modify: `Sources/TaskApp/App/TaskAppShell.swift`

- [ ] **Step 1: Build week/month range controls**

Use a native segmented picker for week/month and date navigation. Reuse the same `PlanMetricsCalculator`; do not create a second formula for insights.

- [ ] **Step 2: Add project filter and completion table**

Show all projects by default. Add project filter menu, completion trend, quadrant distribution, and a table of health deductions sorted by points descending.

- [ ] **Step 3: Add accessible chart summaries**

Each chart receives a sentence summary such as “过去 7 天完成 18 项，周六最高 5 项”。VoiceOver users must not need to inspect bars individually to understand the trend.

- [ ] **Step 4: Verify and commit**

```bash
swift build
swift run TaskApp
```

Expected: board and insights show the same metrics for the same project/range; no discrepancy in health score.

```bash
git add Sources/TaskApp/Features/Insights Sources/TaskApp/App/TaskAppShell.swift
git commit -m "feat: add local task insights"
```

## Plan 03 completion gate

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
```

Manual acceptance:

- A project has exactly one completion column.
- Dragging updates completion state transactionally.
- Metrics are based on real local tasks.
- Health deduction detail sums to the displayed score.
- Empty ranges do not show fabricated chart data.
