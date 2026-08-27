# 正在进行子任务状态与并列关联实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让正在进行池以左右等宽、逐行关联的方式展示子任务，并把状态与备注持久化到已开始的子任务。

**Architecture:** `FocusEntry` 继续是任务加入正在进行池的成员记录，旧任务级状态/备注字段保留仅用于轻量 SwiftData 演进并在首次使用时清空。`Subtask` 保存可选状态、备注和更新时间；`FocusRepository` 是这些字段的唯一写入边界。SwiftUI 将任务标题与共享行双列表分开，行内由专用布局按 `50 / 50` 放置子任务和状态说明，从而同时保持列分离与一一对应。

**Tech Stack:** SwiftData、SwiftUI、XCTest、Swift Package、macOS 14+

---

### Task 0: 恢复测试绿色基线

**Files:**
- Modify: `Tests/TaskPersistenceTests/TaskRepositoryTests.swift:1-4`

- [x] **Step 1: 确认失败原因**

运行：

```bash
swift test --filter TaskRepositoryTests/testSavingAnExistingTaskAsCompletedRemovesItsFocusEntry
```

预期：编译错误 `cannot find 'TaskDraft' in scope`，定位到 `TaskRepositoryTests.swift`；同目标下的 `TaskRepositoryEditingTests.swift` 已显式导入 `TaskDomain`。

- [x] **Step 2: 补齐最小测试依赖**

在现有导入区加入：

```swift
import TaskDomain
```

不修改测试断言或生产代码。

- [x] **Step 3: 验证基线**

运行：

```bash
swift test --filter TaskRepositoryTests
```

预期：`TaskRepositoryTests` 全部通过。

- [x] **Step 4: 提交独立修复**

```bash
git add Tests/TaskPersistenceTests/TaskRepositoryTests.swift
git commit -m "test: restore task repository test import"
```

### Task 1: 持久化子任务状态并淘汰任务级语义

**Files:**
- Modify: `Sources/TaskPersistence/Models/Subtask.swift`
- Modify: `Sources/TaskPersistence/FocusRepository.swift`
- Modify: `Sources/TaskPersistence/TaskRepository.swift`
- Modify: `Tests/TaskPersistenceTests/FocusRepositoryTests.swift`
- Modify: `Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift`

- [x] **Step 1: 写入失败测试**

在 `FocusRepositoryTests` 添加以下行为测试：

```swift
func testStartingAndUpdatingSubtasksKeepsTheirFocusDataIndependent() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let task = try TaskRepository(context: container.mainContext)
        .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归", "确认接口"]))
    let subtasks = task.subtasks.sorted { $0.order < $1.order }
    let repository = FocusRepository(context: container.mainContext)

    try repository.start(subtasks[0])
    try repository.update(subtasks[0], state: .waiting, note: "等待回归结果")
    try repository.start(subtasks[1])

    XCTAssertEqual(subtasks[0].focusState, .waiting)
    XCTAssertEqual(subtasks[0].focusNote, "等待回归结果")
    XCTAssertEqual(subtasks[1].focusState, .focused)
    XCTAssertEqual(subtasks[1].focusNote, "")
    XCTAssertFalse(task.isCompleted)
    XCTAssertNil(task.boardColumn)
}

func testStartingSubtaskClearsLegacyTaskLevelFocusMetadata() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let task = try TaskRepository(context: container.mainContext)
        .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归"]))
    let entry = try FocusRepository(context: container.mainContext)
        .upsert(task: task, state: .blocked, note: "旧备注")

    try FocusRepository(context: container.mainContext).start(try XCTUnwrap(task.subtasks.first))

    XCTAssertEqual(entry.stateRawValue, "")
    XCTAssertEqual(entry.note, "")
}
```

在 `TaskRepositoryEditingTests` 添加：

```swift
func testCompletingSubtaskClearsItsFocusData() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let task = try TaskRepository(context: container.mainContext)
        .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归"]))
    let subtask = try XCTUnwrap(task.subtasks.first)
    try FocusRepository(context: container.mainContext).start(subtask)

    try TaskRepository(context: container.mainContext).setSubtaskCompleted(subtask, isCompleted: true)

    XCTAssertNil(subtask.focusState)
    XCTAssertNil(subtask.focusNote)
    XCTAssertNil(subtask.focusUpdatedAt)
}
```

- [x] **Step 2: 验证 RED**

运行：

```bash
swift test --filter FocusRepositoryTests
swift test --filter TaskRepositoryEditingTests/testCompletingSubtaskClearsItsFocusData
```

预期：编译失败，因为 `Subtask` 尚无焦点字段、`FocusRepository.start/update` 尚不存在。

- [x] **Step 3: 实现最小持久化边界**

在 `Subtask` 增加以下可选存储字段和计算属性：

```swift
public var focusStateRawValue: String?
public var focusNote: String?
public var focusUpdatedAt: Date?

public var focusState: TaskFocusState? {
    get { focusStateRawValue.flatMap(TaskFocusState.init(rawValue:)) }
    set { focusStateRawValue = newValue?.rawValue }
}
```

初始化时三项均为 `nil`。在 `FocusRepository` 增加 `start(_:)` 和 `update(_:state:note:)`：开始默认 `.focused`、空备注和当前时间；更新时修剪备注、写入状态与当前时间；每次开始或更新均清空关联 `FocusEntry` 的 `stateRawValue` / `note` 并保存。新增 `clearFocusData(for:)`，清空一个子任务三项字段；在 `TaskRepository.setSubtaskCompleted` 的完成分支调用它，并在任务完成/删除焦点记录时清除该任务所有子任务焦点数据。

- [x] **Step 4: 验证 GREEN**

运行：

```bash
swift test --filter FocusRepositoryTests
swift test --filter TaskRepositoryEditingTests
```

预期：上述测试和既有编辑测试通过。

- [x] **Step 5: 提交持久化增量**

```bash
git add Sources/TaskPersistence/Models/Subtask.swift Sources/TaskPersistence/FocusRepository.swift Sources/TaskPersistence/TaskRepository.swift Tests/TaskPersistenceTests/FocusRepositoryTests.swift Tests/TaskPersistenceTests/TaskRepositoryEditingTests.swift
git commit -m "feat: store focus state on subtasks"
```

### Task 2: 备份仅保存子任务级状态

**Files:**
- Modify: `Sources/TaskPersistence/Backup/BackupEnvelope.swift`
- Modify: `Sources/TaskPersistence/Backup/BackupService.swift`
- Modify: `Tests/TaskPersistenceTests/BackupServiceTests.swift`

- [x] **Step 1: 写入失败测试**

替换旧的任务级状态往返断言，并添加：

```swift
func testRoundTripPreservesSubtaskFocusDataButDropsLegacyTaskFocusMetadata() throws {
    let container = try ModelContainerFactory.make(inMemory: true)
    let task = try TaskRepository(context: container.mainContext)
        .saveNewTask(TaskDraft(title: "发布", subtasks: ["回归"]))
    let subtask = try XCTUnwrap(task.subtasks.first)
    let entry = try FocusRepository(context: container.mainContext)
        .upsert(task: task, state: .blocked, note: "旧任务备注")
    try FocusRepository(context: container.mainContext).update(subtask, state: .waiting, note: "等待结果")

    let exported = try BackupService(context: container.mainContext).exportSnapshot(now: .now)
    let envelope = try BackupService(context: container.mainContext).validateImport(exported)
    let restored = try ModelContainerFactory.make(inMemory: true)
    try BackupService(context: restored.mainContext).applyImport(envelope)

    let restoredSubtask = try XCTUnwrap(try restored.mainContext.fetch(FetchDescriptor<Subtask>()).first)
    let restoredEntry = try XCTUnwrap(try restored.mainContext.fetch(FetchDescriptor<FocusEntry>()).first)
    XCTAssertEqual(restoredSubtask.focusState, .waiting)
    XCTAssertEqual(restoredSubtask.focusNote, "等待结果")
    XCTAssertEqual(restoredEntry.note, "")
    XCTAssertEqual(entry.note, "")
}
```

同时保留一个 schema v2 JSON 的导入测试：有任务级 `stateRawValue` 与 `note` 时，导入后 `FocusEntry` 仍关联任务但这两个旧值为空。

- [x] **Step 2: 验证 RED**

运行：

```bash
swift test --filter BackupServiceTests
```

预期：新子任务字段不会出现在导出的 `BackupSubtask` 中，往返断言失败。

- [x] **Step 3: 实现版本 3 备份格式**

将 `BackupEnvelope.currentSchemaVersion` 改为 `3`。向 `BackupSubtask` 添加可选 `focusStateRawValue`、`focusNote` 和 `focusUpdatedAt`，并为构造器提供 `nil` 默认值。导出时从 `Subtask` 填入这三项；校验时验证非空状态能由 `TaskFocusState` 解析；导入时恢复到相应 `Subtask`。

`BackupFocusEntry` 仅保留任务成员关系（`id`、`taskID`、创建/更新时间），以自定义 `Decodable` 忽略 v1/v2 中多余的旧 `stateRawValue`、`note`。导入时建立 `FocusEntry(state: .focused, note: "")` 并将 `stateRawValue` 置为空；新导出不序列化旧任务级状态和备注。

- [x] **Step 4: 验证 GREEN**

运行：

```bash
swift test --filter BackupServiceTests
```

预期：子任务状态往返、v2 兼容导入和既有备份校验全部通过。

- [x] **Step 5: 提交备份增量**

```bash
git add Sources/TaskPersistence/Backup/BackupEnvelope.swift Sources/TaskPersistence/Backup/BackupService.swift Tests/TaskPersistenceTests/BackupServiceTests.swift
git commit -m "feat: back up subtask focus state"
```

### Task 3: 渲染左右等宽的关联子任务行

**Files:**
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`
- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`

- [x] **Step 1: 写入失败展示契约测试**

在 `FocusPoolPresentationTests` 添加：

```swift
func testFocusSubtaskRowsUseEqualLinkedColumns() throws {
    let widths = try XCTUnwrap(FocusPoolPresentation.linkedRowColumnWidths(for: 800))

    XCTAssertEqual(FocusPoolPresentation.linkedRowLeftRatio, 0.5, accuracy: 0.000_1)
    XCTAssertEqual(FocusPoolPresentation.linkedRowRightRatio, 0.5, accuracy: 0.000_1)
    XCTAssertEqual(widths.left, widths.right, accuracy: 0.000_1)
    XCTAssertEqual(FocusPoolPresentation.linkedRowDividerWidth, 1)
    XCTAssertTrue(FocusPoolPresentation.linkedRowsShareVerticalAlignment)
    XCTAssertTrue(FocusPoolPresentation.linkedRowsUseCenterConnectionMarker)
}

func testFocusSubtaskStatusIsHiddenUntilStarted() {
    XCTAssertFalse(FocusPoolPresentation.showsSubtaskFocusDetails(state: nil))
    XCTAssertTrue(FocusPoolPresentation.showsSubtaskFocusDetails(state: .focused))
}
```

- [x] **Step 2: 验证 RED**

运行：

```bash
swift test --filter FocusPoolPresentationTests
```

预期：编译失败，因为关联行宽度和状态可见性契约尚不存在。

- [x] **Step 3: 替换任务级详情列**

删除 `FocusEntryRow` 中任务级的 `@State state`、`@State note`、`FocusStateSegmentedControl` 和备注 `TextEditor`。保留标题、优先级色块、移出操作、子任务编辑/完成/排序/新增。

新增 `FocusLinkedSubtaskRow`：左侧继续显示 checkbox、可编辑标题和拖拽手柄；右侧无状态时作为可访问按钮，标签为“开始处理子任务：<标题>”，点击调用 `FocusRepository.start`。有状态时显示既有分段轨道和“子任务备注：<标题>”编辑器，并通过 `FocusRepository.update` 保存。每行使用 `FocusLinkedRowLayout`，中间 `1 pt` 分隔和状态色连接节点，已开始项添加低不透明酸橙关联底纹。标题行显示“任务与子任务”与“状态与说明”。

在 `FocusPoolPresentation` 新增：`linkedRowLeftRatio = 0.5`、`linkedRowRightRatio = 0.5`、`linkedRowDividerWidth = 1`、`linkedRowColumnWidths(for:)`、`showsSubtaskFocusDetails(state:)` 及关联样式布尔契约。窄宽度时 `FocusLinkedRowLayout` 将同一子任务左/右内容纵向排列，不显示中线。

- [x] **Step 4: 验证 GREEN**

运行：

```bash
swift test --filter FocusPoolPresentationTests
swift build
```

预期：展示契约测试通过，调试构建成功。

- [x] **Step 5: 提交 UI 增量**

```bash
git add Sources/TaskApp/Features/FocusPoolScreen.swift Tests/TaskAppTests/FocusPoolPresentationTests.swift
git commit -m "feat: link focus status rows to subtasks"
```

### Task 4: 同步批准规格并进行发布验证

**Files:**
- Modify: `docs/superpowers/specs/2026-08-27-focus-subtask-status-design.md`
- Modify: `docs/ui/task-macos-ui-spec.md`
- Modify: `docs/superpowers/plans/2026-08-27-focus-subtask-status.md`

- [x] **Step 1: 更新 UI 规格**

将 `docs/ui/task-macos-ui-spec.md` 的“5.4 正在做状态”改为：状态/备注属于已开始子任务、卡片双列严格 `50 / 50`、行级共享分隔和连接节点、未开始右侧空白、窄宽度成对堆叠。移除任务级状态控件宽度与 `46 / 54` 列比例说明。

- [x] **Step 2: 标记设计与计划状态**

将设计文档状态改为“已实施”，完成本计划所有复选框，并记录原任务级备注按用户授权删除且不迁移。

- [x] **Step 3: 运行质量门槛**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
git diff --check
```

预期：全部命令成功；优先级扫描与 whitespace 检查没有输出。

- [x] **Step 4: 提交文档与验收记录**

```bash
git add docs/superpowers/specs/2026-08-27-focus-subtask-status-design.md docs/ui/task-macos-ui-spec.md docs/superpowers/plans/2026-08-27-focus-subtask-status.md
git commit -m "docs: record subtask focus status behavior"
```

- [ ] **Step 5: 交给用户进行真实 macOS 检查**

请用户打开 `dist/Task.app`，在默认和最小窗口宽度、深色模式及 VoiceOver 下验证：左/右列等宽并按行关联；状态与备注只跟随开始处理的子任务；未开始项为空；完成子任务或完成任务后不会留下状态/备注。
