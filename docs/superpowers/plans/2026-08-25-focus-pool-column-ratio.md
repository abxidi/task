# 正在进行任务卡 46 / 54 分栏实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将正在进行任务卡的详情列和子任务列调整为可验证的 46 / 54 宽度分配。

**Architecture:** 在既有 `FocusPoolPresentation` 中保留纯布局常量和列宽计算，使 SwiftUI 视图不含比例业务决策。`FocusEntryColumnsLayout` 在同一次 SwiftUI 布局中直接接收父容器宽度并应用计算值，避免 `ScrollView` 内的异步几何测量造成内容溢出；双列状态同时保证 `276 pt` 详情列和 `280 pt` 子任务列的下限，低于下限时改为纵向堆叠。

**Tech Stack:** SwiftUI、XCTest、Swift Package、macOS 14+

---

### Task 1: 锁定 46 / 54 布局契约

**Files:**

- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`

- [x] **Step 1: 写入失败测试**

```swift
func testFocusCardColumnsUseTheApproved46To54Ratio() {
    let widths = FocusPoolPresentation.columnWidths(for: 1_001)

    XCTAssertEqual(FocusPoolPresentation.leftColumnRatio, 0.46, accuracy: 0.000_1)
    XCTAssertEqual(FocusPoolPresentation.rightColumnRatio, 0.54, accuracy: 0.000_1)
    XCTAssertEqual(widths.left, 441.6, accuracy: 0.000_1)
    XCTAssertEqual(widths.right, 518.4, accuracy: 0.000_1)
}

func testFocusCardColumnsPreserveTheSubtaskMinimumWidth() {
    let widths = FocusPoolPresentation.columnWidths(for: 500)

    XCTAssertEqual(widths.left, 179, accuracy: 0.000_1)
    XCTAssertEqual(widths.right, FocusPoolPresentation.subtaskColumnMinWidth, accuracy: 0.000_1)
}
```

- [x] **Step 2: 验证 RED**

Run: `swift test --filter FocusPoolPresentationTests`

Expected: 编译失败，因为比例常量和 `columnWidths(for:)` 尚不存在。

- [x] **Step 3: 实现最小布局计算与 SwiftUI 接入**

在 `FocusPoolPresentation` 中定义 `leftColumnRatio = 0.46`、`rightColumnRatio = 0.54`、`dividerWidth = 1`、双列最小宽度和返回 `FocusCardColumnWidths` 的 `columnWidths(for:)`。计算时从实际可用宽度扣除两段现有 `20 pt` 间距和 `1 pt` 分隔线，随后按比例分配；不足双列下限或收到非有限宽度时不返回列宽。

在 `FocusEntryColumnsLayout` 中通过 `Layout.sizeThatFits` 和 `Layout.placeSubviews` 使用父容器宽度，并将计算后的 `width` 分别提供给 `leftColumn` 和 `subtasksColumn`。无界提议回退为有限理想宽度；可用宽度不足双列下限时纵向放置两列并隐藏分隔线，避免首帧零宽和内容溢出。

- [x] **Step 4: 验证 GREEN**

Run: `swift test --filter FocusPoolPresentationTests && swift build`

Expected: FocusPool 展示测试通过，调试构建成功。

- [x] **Step 5: 更新计划状态**

将本任务所有复选框标为完成。

### Task 2: 发布级验证与原子提交

**Files:**

- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift`
- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`
- Modify: `docs/ui/task-macos-ui-spec.md`
- Create: `docs/superpowers/specs/2026-08-25-focus-pool-column-ratio-design.md`
- Create: `docs/superpowers/plans/2026-08-25-focus-pool-column-ratio.md`

- [x] **Step 1: 运行质量门槛**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
git diff --check
```

Expected: 每条命令成功；旧优先级范围扫描与空白错误检查均无输出。

- [ ] **Step 2: 用实际 macOS 窗口检查（由用户自行完成）**

运行 `dist/Task.app`，在默认窗口、最小支持窗口及深色模式下确认：双列时分隔线约位于可用列宽的 46% 处，右列可读；低于双列下限时两列上下堆叠、状态控件和备注不重叠；VoiceOver 标签未变化。深色系统外观下应用仍保持既有浅色静态表面色，该既有深色模式问题不在本变更范围。

- [x] **Step 3: 提交单一可回滚增量**

```bash
git add Sources/TaskApp/Features/FocusPoolScreen.swift Tests/TaskAppTests/FocusPoolPresentationTests.swift docs/ui/task-macos-ui-spec.md docs/superpowers/specs/2026-08-25-focus-pool-column-ratio-design.md docs/superpowers/plans/2026-08-25-focus-pool-column-ratio.md
git commit -m "fix: shift focus card divider left"
```

Expected: 提交只包含本次分栏比例、测试和对应文档。
