# 任务编辑器上下子任务入口实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在任务编辑器子任务列表的上下两端提供输入入口，上方首位插入、下方保持追加。

**Architecture:** `TaskDraft` 负责维护子任务及其 ID、完成状态的并行数组；`SubtaskEditor` 为每个视觉入口维护独立草稿文本，通过布尔插入意图调用现有自动保存链路。无需改动 SwiftData 或仓储层。

**Tech Stack:** Swift、SwiftUI、XCTest、Swift Package、macOS 14+

---

### Task 1: 锁定首位插入与双入口契约

**Files:**
- Modify: `Tests/TaskDomainTests/TaskDraftTests.swift`
- Modify: `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift`

- [x] **Step 1: 编写失败测试**

新增 `TaskDraft.insertSubtaskAtBeginning(_:)` 的测试，断言新增项位于未完成区首位、其 UUID 位于首位且完成项仍在末尾；新增展示测试，断言 `TaskEditorSubtaskEntryStyle` 声明上下入口和对应 VoiceOver 标签。

- [x] **Step 2: 验证 RED**

运行 `swift test --filter 'TaskDraftTests|TaskEditorTitleMetricsTests'`。预期因首位插入 API 与双入口展示契约尚不存在而失败。

### Task 2: 实现上下入口

**Files:**
- Modify: `Sources/TaskDomain/TaskDraft.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/SubtaskEditor.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift`

- [x] **Step 1: 实现领域首位插入**

在 `TaskDraft` 中标准化现有数据后，在索引 0 同时插入标题、`false` 完成状态和新 UUID。

- [x] **Step 2: 接入两个输入行**

将 `SubtaskEditor.onAdd` 扩展为携带首位插入意图的回调；在现有行列表前后渲染共享的输入行。`TaskEditorSheet` 将首位意图映射为 `TaskDraft.insertSubtaskAtBeginning(_:)`，其余情况继续调用 `addSubtask(_:)`。

- [x] **Step 3: 验证 GREEN**

运行 `swift test --filter 'TaskDraftTests|TaskEditorTitleMetricsTests'` 和 `swift build`。预期测试和调试构建通过。

### Task 3: 同步规范并发布验证

**Files:**
- Modify: `docs/ui/task-macos-ui-spec.md`
- Create: `docs/superpowers/specs/2026-08-21-task-editor-dual-subtask-entry-design.md`
- Create: `docs/superpowers/plans/2026-08-21-task-editor-dual-subtask-entry.md`

- [x] **Step 1: 更新 UI 规范**

说明上下两个输入入口、上方首位插入和下方追加的语义。

- [ ] **Step 2: 运行质量门槛并提交**

运行 `swift test`、`swift build -c release`、`./scripts/package_app.sh`、`codesign --verify --deep --strict dist/Task.app`、旧优先级范围扫描和 `git diff --check`。仅暂存本计划列出的文件，使用提交信息 `feat: add task editor subtask entry at top`。
