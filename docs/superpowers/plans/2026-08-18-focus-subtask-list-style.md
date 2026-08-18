# 正在进行子任务列表样式对齐实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让“正在进行”子任务列表复用任务编辑器的标题字体契约。

**Architecture:** 在现有 `FocusPoolPresentation` 中增加标题字体常量；视图仅读取该常量，不改变行高、间距、事件处理或领域逻辑。通过展示契约测试验证字体数值，随后完成 SwiftUI 接入。

**Tech Stack:** SwiftUI、XCTest、Swift Package、macOS 14+

---

### Task 1: 锁定样式契约

**Files:**
- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`

- [x] **Step 1: Write the failing test**

在 `FocusPoolPresentationTests` 中增加：

```swift
func testFocusSubtaskRowsMatchTaskEditorBaseStyle() {
    XCTAssertEqual(FocusPoolPresentation.subtaskTitleFontSize, 12)
}
```

- [x] **Step 2: Verify RED**

运行 `swift test --filter FocusPoolPresentationTests`，预期因样式常量尚不存在而编译失败。

- [x] **Step 3: Implement the minimal presentation constant**

在 `FocusPoolPresentation` 中增加 `subtaskTitleFontSize = 12`，不修改现有行布局常量。

- [x] **Step 4: Verify GREEN**

再次运行 `swift test --filter FocusPoolPresentationTests`，确认测试通过。

- [x] **Step 5: Commit**

```bash
git add Sources/TaskApp/Features/FocusPoolScreen.swift Tests/TaskAppTests/FocusPoolPresentationTests.swift
git commit -m "test: define focus subtask row style contract"
```

### Task 2: 接入正在进行子任务字体

**Files:**
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`

- [x] **Step 1: Update the subtask fonts**

将 `FocusSubtaskTitleEditor` 和 `addSubtaskInput` 的字体改为 `FocusPoolPresentation.subtaskTitleFontSize`；保持复选框 frame、行 padding 和最小高度原值。

- [x] **Step 2: Verify focused tests and build**

运行 `swift test --filter FocusPoolPresentationTests` 和 `swift build -c release`，确认样式改动未破坏 FocusPool 及应用编译。

- [x] **Step 3: Commit**

```bash
git add Sources/TaskApp/Features/FocusPoolScreen.swift
git commit -m "fix: align focus subtask row styling"
```

### Task 3: Run release validation

**Files:**
- Verify only; no additional source changes expected.

- [x] **Step 1: Run required quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

- [x] **Step 2: Review the final diff**

确认仅涉及 FocusPool 样式契约、实现和本次设计/计划文档；不包含 API Key、模型或行为变更。
