# Task macOS 02 Core Task Experience Implementation Plan

> **状态（2026-07-31）**：本计划中的“任务设置”工具栏和侧栏实现已被用户确认的“内容优先、属性内联”方案替代。任务编辑的现行行为以产品规格第 5 节、UI 规范第 6 节和当前源码为准；下方历史步骤仅保留交接记录。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付无需 AI 或额外设置即可使用的任务闭环，包括任务列表、内容优先编辑器和严格 `-3...3` 的正方形优先级地图。

**Architecture:** 坐标吸附、排序和草稿验证放在 `TaskDomain`，SwiftData 写入放在 `TaskPersistence`，SwiftUI View 只负责展示和用户事件。地图通过不可变 snapshot 渲染，并用 repository closure 持久化坐标。

**Tech Stack:** SwiftUI、SwiftData、TaskDomain、XCTest、macOS 14+

---

## 前置条件

计划 01 的完成门必须通过。先打开 `docs/ui/task-ui-reference.html`，拖动右上角任务点并切换“任务编辑”视图，确认实现目标。

## 文件结构

```text
Sources/TaskDomain/PriorityGridMath.swift
Sources/TaskDomain/TaskSort.swift
Sources/TaskDomain/TaskDraft.swift
Sources/TaskPersistence/TaskRepository.swift
Sources/TaskApp/Design/Color+Hex.swift
Sources/TaskApp/Design/TaskDesignTokens.swift
Sources/TaskApp/Features/PriorityMap/PriorityMarkerView.swift
Sources/TaskApp/Features/PriorityMap/PriorityMapView.swift
Sources/TaskApp/Features/PriorityMap/PriorityMapScreen.swift
Sources/TaskApp/Features/TaskList/TaskListScreen.swift
Sources/TaskApp/Features/TaskEditor/TaskEditorModel.swift
Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift
Sources/TaskApp/Features/TaskEditor/SubtaskEditor.swift
Sources/TaskApp/Features/TaskEditor/TaskSettingsInspector.swift
Tests/TaskDomainTests/PriorityGridMathTests.swift
Tests/TaskDomainTests/TaskSortTests.swift
Tests/TaskDomainTests/TaskDraftTests.swift
Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift
```

### Task 1: Implement grid math and sorting with TDD

**Files:**

- Create: `Tests/TaskDomainTests/PriorityGridMathTests.swift`
- Create: `Tests/TaskDomainTests/TaskSortTests.swift`
- Create: `Sources/TaskDomain/PriorityGridMath.swift`
- Create: `Sources/TaskDomain/TaskSort.swift`

- [ ] **Step 1: Write failing grid tests**

```swift
import XCTest
@testable import TaskDomain

final class PriorityGridMathTests: XCTestCase {
    func testCoordinateToNormalizedPosition() {
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: -3), 0, accuracy: 0.0001)
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: 0), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PriorityGridMath.normalizedPosition(for: 3), 1, accuracy: 0.0001)
    }

    func testNormalizedPositionSnapsToSevenValues() {
        XCTAssertEqual(PriorityGridMath.value(at: 0), -3)
        XCTAssertEqual(PriorityGridMath.value(at: 0.49), 0)
        XCTAssertEqual(PriorityGridMath.value(at: 0.84), 2)
        XCTAssertEqual(PriorityGridMath.value(at: 1), 3)
    }

    func testClampsPointerOutsidePlot() {
        XCTAssertEqual(PriorityGridMath.value(at: -0.5), -3)
        XCTAssertEqual(PriorityGridMath.value(at: 1.5), 3)
    }
}
```

- [ ] **Step 2: Write failing sort tests**

```swift
import Foundation
import XCTest
@testable import TaskDomain

final class TaskSortTests: XCTestCase {
    func testPrioritySortUsesImportanceThenUrgencyThenDueDateThenCreation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let values = [
            TaskSortValue(id: "a", urgency: 3, importance: 1, dueAt: nil, createdAt: now),
            TaskSortValue(id: "b", urgency: 1, importance: 3, dueAt: now.addingTimeInterval(100), createdAt: now),
            TaskSortValue(id: "c", urgency: 3, importance: 3, dueAt: now.addingTimeInterval(200), createdAt: now),
        ]
        XCTAssertEqual(values.sorted(by: TaskSort.priority).map(\.id), ["c", "b", "a"])
    }
}
```

- [ ] **Step 3: Verify failure**

```bash
swift test --filter PriorityGridMathTests
swift test --filter TaskSortTests
```

Expected: both commands fail because the types do not exist.

- [ ] **Step 4: Implement pure grid math**

```swift
public enum PriorityGridMath {
    public static func normalizedPosition(for value: Int) -> Double {
        precondition(PriorityCoordinate.approvedRange.contains(value))
        return Double(value + 3) / 6
    }

    public static func value(at normalizedPosition: Double) -> Int {
        let clamped = min(max(normalizedPosition, 0), 1)
        return Int((clamped * 6).rounded()) - 3
    }
}
```

- [ ] **Step 5: Implement the stable priority comparator**

```swift
import Foundation

public struct TaskSortValue<ID: Comparable>: Equatable {
    public let id: ID
    public let urgency: Int
    public let importance: Int
    public let dueAt: Date?
    public let createdAt: Date

    public init(id: ID, urgency: Int, importance: Int, dueAt: Date?, createdAt: Date) {
        self.id = id
        self.urgency = urgency
        self.importance = importance
        self.dueAt = dueAt
        self.createdAt = createdAt
    }
}

public enum TaskSort {
    public static func priority<ID>(_ lhs: TaskSortValue<ID>, _ rhs: TaskSortValue<ID>) -> Bool {
        if lhs.importance != rhs.importance { return lhs.importance > rhs.importance }
        if lhs.urgency != rhs.urgency { return lhs.urgency > rhs.urgency }
        if lhs.dueAt != rhs.dueAt { return (lhs.dueAt ?? .distantFuture) < (rhs.dueAt ?? .distantFuture) }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id < rhs.id
    }
}
```

- [ ] **Step 6: Verify and commit**

```bash
swift test --filter PriorityGridMathTests
swift test --filter TaskSortTests
git add Sources/TaskDomain Tests/TaskDomainTests
git commit -m "feat: add priority grid math and sorting"
```

Expected: both test suites pass.

### Task 2: Add task draft validation and repository editing

**Files:**

- Create: `Tests/TaskDomainTests/TaskDraftTests.swift`
- Create: `Sources/TaskDomain/TaskDraft.swift`
- Create: `Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift`
- Modify: `Sources/TaskPersistence/TaskRepository.swift`

- [ ] **Step 1: Write failing draft tests**

```swift
import XCTest
@testable import TaskDomain

final class TaskDraftTests: XCTestCase {
    func testOnlyTitleIsRequired() throws {
        let draft = TaskDraft(title: "  Draft launch plan  ")
        XCTAssertEqual(try draft.validated().title, "Draft launch plan")
        XCTAssertEqual(try draft.validated().coordinate, .init(uncheckedUrgency: 0, importance: 0))
    }

    func testEmptyTitleIsRejected() {
        XCTAssertThrowsError(try TaskDraft(title: "   ").validated())
    }

    func testSubtasksPreserveOrder() throws {
        let draft = TaskDraft(title: "Plan", subtasks: ["Second", "First"])
        XCTAssertEqual(try draft.validated().subtasks, ["Second", "First"])
    }
}
```

- [ ] **Step 2: Implement the domain draft**

```swift
import Foundation

public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var details: String
    public var coordinate: PriorityCoordinate
    public var dueAt: Date?
    public var reminderAt: Date?
    public var estimatedMinutes: Int?
    public var subtasks: [String]

    public init(
        title: String,
        details: String = "",
        coordinate: PriorityCoordinate = .init(uncheckedUrgency: 0, importance: 0),
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        estimatedMinutes: Int? = nil,
        subtasks: [String] = []
    ) {
        self.title = title
        self.details = details
        self.coordinate = coordinate
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.estimatedMinutes = estimatedMinutes
        self.subtasks = subtasks
    }

    public func validated() throws -> Self {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw TaskDraftError.emptyTitle }
        copy.subtasks = subtasks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let minutes = estimatedMinutes, minutes <= 0 { throw TaskDraftError.invalidEstimate }
        return copy
    }
}

public enum TaskDraftError: Error, Equatable {
    case emptyTitle
    case invalidEstimate
}
```

- [ ] **Step 3: Write repository editing tests**

```swift
import SwiftData
import XCTest
import TaskDomain
@testable import TaskPersistence

@MainActor
final class TaskRepositoryEditingTests: XCTestCase {
    func testSaveDraftPersistsDescriptionPriorityAndSubtasks() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let draft = TaskDraft(
            title: "Launch",
            details: "Context",
            coordinate: .init(uncheckedUrgency: 3, importance: 3),
            subtasks: ["Price", "Channels"]
        )
        let item = try repository.saveNewTask(draft)
        XCTAssertEqual(item.details, "Context")
        XCTAssertEqual(item.urgency, 3)
        XCTAssertEqual(item.importance, 3)
        XCTAssertEqual(item.subtasks.sorted { $0.order < $1.order }.map(\.title), ["Price", "Channels"])
    }
}
```

- [ ] **Step 4: Add repository draft saving**

```swift
@discardableResult
public func saveNewTask(_ input: TaskDraft) throws -> TaskItem {
    let draft = try input.validated()
    let item = TaskItem(title: draft.title)
    item.details = draft.details
    item.urgency = draft.coordinate.urgency
    item.importance = draft.coordinate.importance
    item.dueAt = draft.dueAt
    item.reminderAt = draft.reminderAt
    item.estimatedMinutes = draft.estimatedMinutes
    item.subtasks = draft.subtasks.enumerated().map { index, title in
        Subtask(title: title, order: index)
    }
    context.insert(item)
    try context.save()
    return item
}
```

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter TaskDraftTests
swift test --filter TaskRepositoryEditingTests
git add Sources/TaskDomain/TaskDraft.swift Sources/TaskPersistence/TaskRepository.swift Tests
git commit -m "feat: persist content-first task drafts"
```

### Task 3: Add design tokens and the priority marker

**Files:**

- Create: `Sources/TaskApp/Design/Color+Hex.swift`
- Create: `Sources/TaskApp/Design/TaskDesignTokens.swift`
- Create: `Sources/TaskApp/Features/PriorityMap/PriorityMarkerView.swift`

- [ ] **Step 1: Add the color bridge**

```swift
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
```

- [ ] **Step 2: Add focused visual tokens**

```swift
import SwiftUI

enum TaskDesignTokens {
    static let acid = Color(hex: 0xD8FF5B)
    static let panelRadius: CGFloat = 6
    static let markerSize: CGFloat = 24
    static let markerSelectedSize: CGFloat = 28
    static let plotInset: CGFloat = 24
}
```

- [ ] **Step 3: Implement marker encoding**

```swift
import SwiftUI
import TaskDomain

struct PriorityMarkerView: View {
    let coordinate: PriorityCoordinate
    let title: String
    let isSelected: Bool

    var body: some View {
        let style = try! UrgencyPalette.style(for: coordinate.urgency)
        Text(coordinate.importance > 0 ? "+\(coordinate.importance)" : "\(coordinate.importance)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(style.usesDarkText ? Color(hex: 0x241F1A) : .white)
            .frame(
                width: isSelected ? TaskDesignTokens.markerSelectedSize : TaskDesignTokens.markerSize,
                height: isSelected ? TaskDesignTokens.markerSelectedSize : TaskDesignTokens.markerSize
            )
            .background(Color(hex: style.hex), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.background, lineWidth: 2))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(TaskDesignTokens.acid, lineWidth: 3)
                        .padding(-4)
                }
            }
            .accessibilityLabel("\(title)，紧急度 \(coordinate.urgency)，重要度 \(coordinate.importance)，\(coordinate.quadrant.accessibilityName)")
    }
}

private extension PriorityQuadrant {
    var accessibilityName: String {
        switch self {
        case .actNow: "立即处理"
        case .plan: "重点规划"
        case .delegate: "适当委派"
        case .defer: "稍后处理"
        case .undecided: "待判断"
        }
    }
}
```

- [ ] **Step 4: Build and visually inspect previews**

Add a temporary `#Preview` with urgency values `-3...3`, then run:

```bash
swift build
```

Expected: build succeeds; Xcode preview shows seven distinct backgrounds and signed importance numbers. Remove only the temporary wrapper if it is not useful; keep production previews that compile.

- [ ] **Step 5: Commit**

```bash
git add Sources/TaskApp/Design Sources/TaskApp/Features/PriorityMap/PriorityMarkerView.swift
git commit -m "feat: add priority marker visual encoding"
```

### Task 4: Build the square draggable priority map

**Files:**

- Create: `Sources/TaskApp/Features/PriorityMap/PriorityMapView.swift`
- Create: `Sources/TaskApp/Features/PriorityMap/PriorityMapScreen.swift`
- Modify: `Sources/TaskApp/App/TaskAppShell.swift`

- [ ] **Step 1: Implement coordinate conversion inside a square plot**

```swift
import SwiftUI
import TaskDomain
import TaskPersistence

struct PriorityMapView: View {
    let tasks: [TaskItem]
    @Binding var selection: TaskItem?
    let onMove: (TaskItem, PriorityCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plot = CGRect(origin: .zero, size: .init(width: side, height: side))
                .insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)

            ZStack {
                PriorityGridShape().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                ForEach(tasks) { task in
                    let coordinate = PriorityCoordinate(uncheckedUrgency: task.urgency, importance: task.importance)
                    PriorityMarkerView(coordinate: coordinate, title: task.title, isSelected: selection?.id == task.id)
                        .position(point(for: coordinate, in: plot))
                        .gesture(dragGesture(for: task, plot: plot))
                        .onTapGesture { selection = task }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func point(for coordinate: PriorityCoordinate, in plot: CGRect) -> CGPoint {
        CGPoint(
            x: plot.minX + CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.urgency)) * plot.width,
            y: plot.maxY - CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.importance)) * plot.height
        )
    }

    private func dragGesture(for task: TaskItem, plot: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = (value.location.x - plot.minX) / plot.width
                let y = (plot.maxY - value.location.y) / plot.height
                onMove(task, .init(
                    uncheckedUrgency: PriorityGridMath.value(at: Double(x)),
                    importance: PriorityGridMath.value(at: Double(y))
                ))
            }
    }
}
```

- [ ] **Step 2: Add a seven-line grid shape**

```swift
private struct PriorityGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        let plot = rect.insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)
        var path = Path()
        for value in -3...3 {
            let position = PriorityGridMath.normalizedPosition(for: value)
            let x = plot.minX + CGFloat(position) * plot.width
            let y = plot.maxY - CGFloat(position) * plot.height
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        return path
    }
}
```

- [ ] **Step 3: Build the screen and debounce saves**

`PriorityMapScreen` must query unfinished tasks, keep the selected task, update model values immediately for visual feedback, and debounce `ModelContext.save()` by 150 ms. Use a cancellable `Task<Void, Never>?` owned by the screen model; do not save on every pointer event.

```swift
@MainActor
final class PriorityMoveSaver: ObservableObject {
    private var pending: Task<Void, Never>?
    func schedule(_ operation: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            operation()
        }
    }
}
```

- [ ] **Step 4: Add keyboard movement**

Attach `.onMoveCommand` to the map container. Clamp the selected task with `PriorityCoordinate.clamped`, update one axis by one step, and call the same save path as drag. Confirm `-4` and `+4` can never be produced.

- [ ] **Step 5: Wire the route and verify**

```bash
swift build
swift run TaskApp
```

Expected: priority route shows a square map; points snap to seven positions; resizing keeps `1:1`; arrow keys move the selected point one step.

- [ ] **Step 6: Commit**

```bash
git add Sources/TaskApp/Features/PriorityMap Sources/TaskApp/App/TaskAppShell.swift
git commit -m "feat: add square draggable priority map"
```

### Task 5: Implement task list and quick creation

**Files:**

- Create: `Sources/TaskApp/Features/TaskList/TaskListScreen.swift`
- Modify: `Sources/TaskApp/App/TaskAppShell.swift`
- Modify: `Sources/TaskApp/App/TaskApplication.swift`

- [ ] **Step 1: Add query scopes**

Create an enum for `today`, `nextSevenDays`, `all`, and `completed`. Each scope builds a `FetchDescriptor<TaskItem>` with explicit sort descriptors. Priority sort that cannot be expressed by SwiftData runs after fetch using `TaskSort.priority`.

- [ ] **Step 2: Implement list rows**

Each row shows checkbox, `PriorityMarkerView`, title, optional date, and project. Completing a row updates `isCompleted` and `completedAt` in one save.

```swift
Button {
    item.isCompleted.toggle()
    item.completedAt = item.isCompleted ? .now : nil
    try? modelContext.save()
} label: {
    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
}
.buttonStyle(.plain)
.accessibilityLabel(item.isCompleted ? "标记为未完成" : "标记为已完成")
```

- [ ] **Step 3: Add quick creation**

At the top of all tasks and current filters, provide a one-line field. `Return` calls `TaskRepository.createTask(title:)`, then clears the field. No date/project/priority dialog appears.

- [ ] **Step 4: Wire Command-N**

Replace the disabled menu command from plan 01 with a focused-value action that opens `TaskEditorSheet` using `TaskDraft(title: "")`.

- [ ] **Step 5: Verify and commit**

```bash
swift build
swift run TaskApp
```

Expected: title-only quick creation works, tasks persist after relaunch, and list rows use the same marker encoding as the map.

```bash
git add Sources/TaskApp/Features/TaskList Sources/TaskApp/App
git commit -m "feat: add local task lists and quick creation"
```

### Task 6: Implement the content-first task editor

**Files:**

- Create: `Sources/TaskApp/Features/TaskEditor/TaskEditorModel.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/SubtaskEditor.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/TaskSettingsInspector.swift`

- [ ] **Step 1: Add a draft-owning editor model**

```swift
import SwiftUI
import TaskDomain

@MainActor
final class TaskEditorModel: ObservableObject {
    @Published var draft: TaskDraft
    @Published var isSettingsPresented = false
    @Published var errorMessage: String?

    init(draft: TaskDraft) { self.draft = draft }

    var canSave: Bool {
        guard let validated = try? draft.validated() else { return false }
        return !validated.title.isEmpty
    }
}
```

- [ ] **Step 2: Build the content-first sheet**

The main column must contain only title, description, and `SubtaskEditor`. Put the settings button in the toolbar. Do not show date/project chips in the main column.

```swift
VStack(alignment: .leading, spacing: 20) {
    TextField("任务标题", text: $model.draft.title)
        .textFieldStyle(.plain)
        .font(.system(size: 30, weight: .semibold, design: .serif))
    TextEditor(text: $model.draft.details)
        .frame(minHeight: 160)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
    SubtaskEditor(items: $model.draft.subtasks)
}
.toolbar {
    Button("任务设置", systemImage: "slider.horizontal.3") {
        model.isSettingsPresented.toggle()
    }
}
```

- [ ] **Step 3: Implement continuous subtask creation**

`SubtaskEditor` keeps a separate `newTitle`. On Return: trim; append if non-empty; clear and keep focus. If empty, release focus. Existing rows support toggle, rename, delete, and move.

- [ ] **Step 4: Put the square map first in settings**

`TaskSettingsInspector` order must be:

```swift
VStack(alignment: .leading, spacing: 16) {
    PriorityCoordinateEditor(coordinate: $draft.coordinate)
        .aspectRatio(1, contentMode: .fit)
    Divider()
    DateAndReminderFields(draft: $draft)
    EstimateField(minutes: $draft.estimatedMinutes)
    ProjectAndColumnFields(draft: $draft)
    CompletionField(draft: $draft)
    TagFields(draft: $draft)
}
```

Do not wrap these rows in nested cards. Use native form rows and dividers.

- [ ] **Step 5: Save with keyboard and protect dirty dismissal**

- `Command-Return` validates and saves.
- `Escape` closes only when unchanged; otherwise show confirmation.
- Saving an empty title leaves the sheet open and focuses title.
- Saving without opening settings preserves `(0,0)`, no date, no project, unfinished, no tags.

- [ ] **Step 6: Verify and commit**

```bash
swift test
swift build
swift run TaskApp
```

Manual checks: create a title-only task; create three subtasks by Return; open settings and confirm the square map is first; set `(+3,+3)` and relaunch to verify persistence.

```bash
git add Sources/TaskApp/Features/TaskEditor
git commit -m "feat: add content-first task editor"
```

## Plan 02 completion gate

```bash
swift test
swift build -c release
./scripts/package_app.sh
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

Expected: all tests/build/package commands pass; obsolete-range scan has no matches. The app can create, edit, prioritize, complete, and persist tasks without AI configuration.
