# Task Board Drag Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让任务列表泳道和项目看板的卡片拖动具有完整跟手浮层、源占位、目标插入占位和短促落位动画，并遵守 Reduce Motion。

**Architecture:** 继续使用共享 `BoardDragCoordinator` 和根 overlay，不恢复系统 `onDrag/dropDestination`。协调器增加 dragging/settling 展示阶段并在落位动画完成前保留 session；列组件只渲染源/目标占位，两个 Screen 继续负责最终 SwiftData move。

**Tech Stack:** Swift 6.3、SwiftUI、SwiftData、XCTest、macOS 14+

**References:**

- Apple `Animation.easeOut(duration:)`: https://developer.apple.com/documentation/swiftui/animation/easeout(duration:)
- Apple `EnvironmentValues.accessibilityReduceMotion`: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
- Apple animated completion: https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)
- OSS position preferences and pending-drop state: https://github.com/visfitness/reorderable

---

## File Responsibilities

- `Sources/TaskApp/Features/Board/BoardDragCoordinator.swift`: 拖动/落位状态机；只管理展示状态，不访问 SwiftData。
- `Sources/TaskApp/Features/Board/BoardColumnView.swift`: 源卡片弱化、目标幽灵卡片、目标 frame 上报和动效令牌。
- `Sources/TaskApp/Features/TaskList/TaskListScreen.swift`: 本地泳道目标排序位置、落位完成后的本地任务 move。
- `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`: 项目列目标排序位置、落位完成后的项目任务 move。
- `Tests/TaskAppTests/BoardDragPresentationTests.swift`: 状态机、几何和 Reduce Motion 展示契约。

### Task 1: Add the drag settlement contract with TDD

**Files:**

- Modify: `Tests/TaskAppTests/BoardDragPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/Board/BoardDragCoordinator.swift`
- Modify: `Sources/TaskApp/Features/Board/BoardColumnView.swift`

- [x] **Step 1: Write failing state and geometry tests**

Add tests proving that a session starts in `.dragging`, direct updates work only while dragging, settlement keeps the session alive, the settlement pointer preserves the original grab offset, and completion clears state:

```swift
@MainActor
func testSettlementRetainsSessionAtDestinationUntilCompletion() {
    let coordinator = BoardDragCoordinator()
    coordinator.begin(
        taskID: UUID(),
        sourceColumnID: UUID(),
        boardLocation: CGPoint(x: 100, y: 80),
        sourceFrame: CGRect(x: 40, y: 50, width: 228, height: 92),
        grabOffset: CGPoint(x: 30, y: 20)
    )

    coordinator.settle(to: CGRect(x: 420, y: 160, width: 228, height: 92))

    XCTAssertEqual(coordinator.session?.phase, .settling)
    XCTAssertEqual(coordinator.boardLocation, CGPoint(x: 450, y: 180))
    coordinator.complete()
    XCTAssertNil(coordinator.session)
}
```

Add presentation-token assertions:

```swift
func testMotionContractUsesShortEaseOutDurations() {
    XCTAssertEqual(BoardDragPresentation.liftDuration, 0.14)
    XCTAssertEqual(BoardDragPresentation.dropDuration, 0.18)
    XCTAssertEqual(BoardDragPresentation.placeholderOpacity, 0.35)
}
```

- [x] **Step 2: Run RED**

Run:

```bash
swift test --filter BoardDragPresentationTests
```

Expected: compilation fails because `BoardDragPhase`, `sourceFrame`, `settle(to:)`, `complete()`, and duration constants do not exist.

- [x] **Step 3: Implement the minimal state contract**

Add:

```swift
enum BoardDragPhase: Equatable {
    case dragging
    case settling
}

struct BoardDragSession: Equatable {
    let taskID: UUID
    let sourceColumnID: UUID
    let targetColumnID: UUID
    let boardLocation: CGPoint
    let sourceFrame: CGRect
    let grabOffset: CGPoint
    let phase: BoardDragPhase
}
```

`begin` stores `.dragging`; `update` ignores sessions not in `.dragging`; `settle(to:)` updates `boardLocation` to destination top-leading plus `grabOffset` and changes phase to `.settling`; `complete()` clears the session. Remove the mutating `finish()` API; screens use `BoardDragPresentation.completionDecision` to decide persistence and must not clear session before animation completion.

Add exact presentation tokens:

```swift
static let placeholderOpacity = 0.35
static let liftDuration = 0.14
static let dropDuration = 0.18
static let liftedScale = 1.015
```

- [x] **Step 4: Run GREEN and commit**

```bash
swift test --filter BoardDragPresentationTests
git add Sources/TaskApp/Features/Board/BoardDragCoordinator.swift Sources/TaskApp/Features/Board/BoardColumnView.swift Tests/TaskAppTests/BoardDragPresentationTests.swift
git commit -m "feat: model board drag settlement motion"
```

Expected: focused suite passes with zero failures.

### Task 2: Render the animated target placeholder

**Files:**

- Modify: `Tests/TaskAppTests/BoardDragPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/Board/BoardColumnView.swift`

- [x] **Step 1: Write failing placeholder tests**

Add pure tests for clamping the insertion index and hiding a second placeholder in the source column:

```swift
func testPlaceholderIndexIsClampedToLaneBounds() {
    XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: -1, taskCount: 2), 0)
    XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: 1, taskCount: 2), 1)
    XCTAssertEqual(BoardDragPresentation.placeholderIndex(requested: 9, taskCount: 2), 2)
}

func testSourceLaneDoesNotRenderASecondPlaceholder() {
    XCTAssertFalse(BoardDragPresentation.showsTargetPlaceholder(
        sourceColumnID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        targetColumnID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    ))
}
```

- [x] **Step 2: Run RED**

Run `swift test --filter BoardDragPresentationTests`.

Expected: compilation fails because the placeholder helpers do not exist.

- [x] **Step 3: Implement the placeholder view and frame preference**

`BoardColumnView` receives `draggedTask: TaskItem?` and `targetPlaceholderIndex: Int?`. Inside `LazyVStack`, insert a `BoardTaskCard` ghost before the requested index or after the last card:

```swift
BoardTaskCard(task: task)
    .opacity(0.28)
    .overlay(
        RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
            .fill(TaskDesignTokens.acid.opacity(0.12))
    )
    .allowsHitTesting(false)
    .accessibilityHidden(true)
```

Report the placeholder global frame through `BoardDropPlaceholderFramePreferenceKey` keyed by column ID. Animate only changes to the placeholder index/target with `.easeOut(duration: 0.14)`; do not attach an animation keyed by pointer location. Source opacity and target border use the same short animation. With Reduce Motion, replace scale/move transitions with opacity only.

- [x] **Step 4: Run GREEN and commit**

```bash
swift test --filter BoardDragPresentationTests
swift build
git add Sources/TaskApp/Features/Board/BoardColumnView.swift Tests/TaskAppTests/BoardDragPresentationTests.swift
git commit -m "feat: animate board drop placeholders"
```

Expected: tests and debug build pass.

### Task 3: Settle the floating card before persistence

**Files:**

- Modify: `Sources/TaskApp/Features/TaskList/TaskListScreen.swift`
- Modify: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`
- Modify: `Tests/TaskAppTests/BoardDragPresentationTests.swift`

- [x] **Step 1: Add failing ownership and completion tests**

Replace the wrapper-state assertion with a direct coordinator ownership contract, and cover `.move`, `.noMove`, and `.cancel` decisions retaining the session until explicit completion.

Run `swift test --filter BoardDragPresentationTests` and confirm the expected RED failure.

- [x] **Step 2: Wire target ordering and placeholder frames**

Both screens own one `@StateObject private var dragCoordinator = BoardDragCoordinator()` plus `[UUID: CGRect]` placeholder frames. For the active task and target column, compute the index it will occupy under the existing sort:

- Task list lanes: append the active task to the target tasks, apply the existing `TaskSort.priority`, then take its index.
- Project columns: append the active task and sort by existing `manualOrder`, then take its index.

Pass the task and index to `BoardColumnView`. No `manualOrder` or model field changes are introduced.

- [x] **Step 3: Animate settlement and then persist**

On pointer end:

1. Resolve `.move`, `.noMove`, or `.cancel`.
2. For a move, animate the overlay to the target placeholder frame with `easeOut(duration: 0.18)`.
3. For no-move/cancel, animate back to `session.sourceFrame`.
4. Use SwiftUI animation completion to call the existing move service only for `.move`, then call `complete()`.
5. On persistence failure, preserve the error alert and return the floating card to the source before clearing.
6. Under Reduce Motion, skip scale/travel and use a short opacity transition before the same persistence decision.

The overlay uses the measured `sourceFrame.width`, retains the original grab offset, uses scale `1.015` and a stronger shadow only in `.dragging`, and remains at a high `zIndex` through `.settling`.

- [x] **Step 4: Verify focused behavior and commit**

```bash
swift test --filter BoardDragPresentationTests
swift test --filter BoardWorkflowServiceTests
swift build
git add Sources/TaskApp/Features/TaskList/TaskListScreen.swift Sources/TaskApp/Features/Board/ProjectBoardScreen.swift Tests/TaskAppTests/BoardDragPresentationTests.swift
git commit -m "feat: settle board cards into target lanes"
```

Expected: focused suites and debug build pass.

### Task 4: Verify, package, install, and reopen

- [x] **Step 1: Run project quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

Expected: test/build/package/sign commands exit 0; obsolete-range scan prints no production matches.

- [x] **Step 2: Review the final diff**

Review tests first, then correctness, readability, architecture, security, and hot-path performance. Confirm continuous pointer updates have no implicit animation, no new dependency or model field exists, and only one root overlay is rendered.

- [x] **Step 3: Install and reopen**

Terminate running `TaskApp`, replace `/Applications/Task.app` with `dist/Task.app`, verify the installed signature, then open `/Applications/Task.app`. Confirm the running executable path resolves inside `/Applications/Task.app`.
