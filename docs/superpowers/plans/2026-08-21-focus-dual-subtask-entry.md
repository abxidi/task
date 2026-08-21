# 正在进行双入口子任务创建实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让“正在进行”子任务列表支持从上方插入和从下方追加，并持久化正确的顺序。

**Architecture:** `TaskRepository` 继续负责子任务顺序及 SwiftData 保存；新增的首位插入 API 会重编号现有项。`FocusEntryRow` 保留视图层输入与错误显示职责，通过两个绑定文本和一个位置参数使用仓储 API，不在 View 中计算持久化顺序。

**Tech Stack:** Swift 5.9、SwiftUI、SwiftData、XCTest、macOS 14+

---

### Task 1: 定义双入口与首位插入契约

**Files:**
- Modify: `Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift`
- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`

- [ ] **Step 1: 写入持久化失败测试**

```swift
func testAddingSubtaskAtTheBeginningRenumbersExistingItems() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let repository = TaskRepository(context: container.mainContext)
    let item = try repository.saveNewTask(
        TaskDraft(
            title: "正在做",
            subtasks: ["未完成", "已完成"],
            subtaskCompletion: [false, true]
        )
    )

    _ = try repository.insertSubtaskAtBeginning(to: item, title: "优先处理")

    let ordered = item.subtasks.sorted { $0.order < $1.order }
    XCTAssertEqual(ordered.map(\.title), ["优先处理", "未完成", "已完成"])
    XCTAssertEqual(ordered.map(\.order), [0, 1, 2])
    XCTAssertEqual(ordered.map(\.isCompleted), [false, false, true])
}
```

- [ ] **Step 2: 验证 RED**

运行：`swift test --filter TaskRepositoryEditingTests/testAddingSubtaskAtTheBeginningRenumbersExistingItems`

预期：因 `insertSubtaskAtBeginning(to:title:)` 不存在而编译失败。

- [ ] **Step 3: 写入展示失败测试**

```swift
func testFocusPoolProvidesDistinctSubtaskCreationEntrances() {
    XCTAssertTrue(FocusPoolPresentation.hasTopSubtaskEntry)
    XCTAssertTrue(FocusPoolPresentation.hasBottomSubtaskEntry)
    XCTAssertEqual(FocusPoolPresentation.topSubtaskEntryAccessibilityLabel, "从上方添加子任务")
    XCTAssertEqual(FocusPoolPresentation.bottomSubtaskEntryAccessibilityLabel, "从下方添加子任务")
}
```

- [ ] **Step 4: 验证 RED**

运行：`swift test --filter FocusPoolPresentationTests/testFocusPoolProvidesDistinctSubtaskCreationEntrances`

预期：因展示契约尚不存在而编译失败。

- [ ] **Step 5: 提交测试契约**

```bash
git add Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift Tests/TaskAppTests/FocusPoolPresentationTests.swift
git commit -m "test: define dual subtask entry contracts"
```

### Task 2: 实现首位插入与双入口界面

**Files:**
- Modify: `Sources/TaskPersistence/TaskRepository.swift`
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`

- [ ] **Step 1: 实现首位插入 API**

```swift
@discardableResult
public func insertSubtaskAtBeginning(to item: TaskItem, title: String) throws -> Subtask {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { throw TaskRepositoryError.emptySubtaskTitle }

    let ordered = item.subtasks.sorted { $0.order < $1.order }
    let subtask = Subtask(title: trimmedTitle, order: 0)
    for (index, existing) in ordered.enumerated() {
        existing.order = index + 1
    }
    subtask.task = item
    item.subtasks = [subtask] + ordered
    item.updatedAt = .now
    context.insert(subtask)
    try context.save()
    return subtask
}
```

- [ ] **Step 2: 接入双输入行**

在 `FocusEntryRow` 将单个 `newSubtaskTitle` 拆为 `topSubtaskTitle` 和 `bottomSubtaskTitle`。在子任务标题后渲染顶部输入行，在子任务列表后渲染底部输入行；两者复用 `subtaskInput(text:accessibilityLabel:onSubmit:)`，并分别调用首位插入和已有末尾追加方法。

- [ ] **Step 3: 验证 GREEN**

运行：

```bash
swift test --filter TaskRepositoryEditingTests
swift test --filter FocusPoolPresentationTests
swift build -c release
```

预期：全部通过。

- [ ] **Step 4: 提交功能**

```bash
git add Sources/TaskPersistence/TaskRepository.swift Sources/TaskApp/Features/FocusPoolScreen.swift
git commit -m "feat: add top subtask entry in focus pool"
```

### Task 3: 运行发布验证

**Files:**
- Modify: `docs/superpowers/plans/2026-08-21-focus-dual-subtask-entry.md`

- [ ] **Step 1: 运行完整质量门槛**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\\+5(?![0-9])|11 级|11 个' Sources
```

预期：测试、构建、打包和签名均成功；最后一条命令无生产源码匹配。

- [ ] **Step 2: 原生运行态检查**

启动 `dist/Task.app`，在“正在进行”中验证顶部创建首位、底部创建末位、`Return`、`Command-Return` 和 VoiceOver 标签。

- [ ] **Step 3: 完成计划并提交**

```bash
git add docs/superpowers/plans/2026-08-21-focus-dual-subtask-entry.md
git commit -m "docs: complete dual subtask entry plan"
```
