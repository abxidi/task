# 已完成任务移出正在进行实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 任务完成时删除正在进行记录，重新打开不自动恢复。

**Architecture:** 在 `TaskPersistence` 内部集中删除 `FocusEntry`，使任务列表、任务编辑器和项目看板三个完成入口保持一致。完成状态、泳道迁移与焦点记录删除在各自服务的同一 `ModelContext.save()` 中持久化；重新打开分支不调用删除或创建逻辑。

**Tech Stack:** SwiftData、XCTest、Swift Package、macOS 14+

---

### Task 1: 锁定完成时移出正在进行的持久化契约

**Files:**

- Modify: `Tests/TaskPersistenceTests/TaskRepositoryTests.swift`
- Modify: `Tests/TaskPersistenceTests/BoardWorkflowServiceTests.swift`
- Modify: `Sources/TaskPersistence/FocusRepository.swift`
- Modify: `Sources/TaskPersistence/TaskRepository.swift`
- Modify: `Sources/TaskPersistence/BoardWorkflowService.swift`

- [x] **Step 1: 写入失败测试**

```swift
func testCompletingLocalTaskRemovesItsFocusEntry() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let task = try TaskRepository(context: container.mainContext).createTask(title: "完成任务")
    _ = try FocusRepository(context: container.mainContext).upsert(task: task, state: .focused, note: "收尾")

    try TaskRepository(context: container.mainContext).setCompleted(task, isCompleted: true)

    XCTAssertNil(task.focusEntry)
    XCTAssertTrue(try FocusRepository(context: container.mainContext).fetchEntries().isEmpty)
}

func testMovingProjectTaskToCompletionColumnRemovesItsFocusEntry() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let project = try ProjectRepository(context: container.mainContext).createProject(name: "Launch", colorHex: "#F07446")
    let done = try XCTUnwrap(project.boardColumns.first(where: \.isCompletionColumn))
    let task = TaskItem(title: "发布")
    task.project = project
    container.mainContext.insert(task)
    _ = try FocusRepository(context: container.mainContext).upsert(task: task, state: .focused, note: "")

    try BoardWorkflowService(context: container.mainContext).move(task, to: done)

    XCTAssertNil(task.focusEntry)
}
```

- [ ] **Step 2: 验证 RED（按用户要求不执行）**

Run: `swift test --filter 'TaskRepositoryTests|BoardWorkflowServiceTests'`

Expected: 两项新测试失败，因为完成流程尚未删除 `FocusEntry`。

- [x] **Step 3: 实现最小删除帮助方法与两个完成入口接入**

```swift
func removeFocusEntry(for task: TaskItem, from context: ModelContext) {
    guard let entry = task.focusEntry else { return }
    task.focusEntry = nil
    context.delete(entry)
}
```

在 `TaskRepository.setCompleted(_:isCompleted:)`、`TaskRepository` 的任务编辑保存路径与 `BoardWorkflowService.move(_:to:now:)` 的完成分支、`context.save()` 前调用该方法；重新打开分支不调用它。

- [ ] **Step 4: 验证 GREEN（按用户要求不执行）**

Run: `swift test --filter 'TaskRepositoryTests|BoardWorkflowServiceTests|FocusRepositoryTests'`

Expected: 指定测试全部通过，完成任务没有 `FocusEntry`，重新打开不新增记录。

- [x] **Step 5: 更新产品与 UI 行为说明**

在 `docs/superpowers/specs/2026-07-13-task-macos-design.md` 的“正在做”规则和 `docs/ui/task-macos-ui-spec.md` 的“正在做状态”规则中，明确完成任务会从正在进行移除、重新打开不自动恢复。

- [x] **Step 6: 提交单一可回滚增量**

```bash
git add Sources/TaskPersistence/FocusRepository.swift Sources/TaskPersistence/TaskRepository.swift Sources/TaskPersistence/BoardWorkflowService.swift Tests/TaskPersistenceTests/TaskRepositoryTests.swift Tests/TaskPersistenceTests/BoardWorkflowServiceTests.swift docs/superpowers/specs/2026-07-13-task-macos-design.md docs/ui/task-macos-ui-spec.md docs/superpowers/specs/2026-08-25-completed-task-focus-removal-design.md docs/superpowers/plans/2026-08-25-completed-task-focus-removal.md
git commit -m "fix: remove completed tasks from focus pool"
```

Expected: 提交只包含完成任务移出正在进行的持久化规则、测试与文档。
