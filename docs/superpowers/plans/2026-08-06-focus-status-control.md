# 正在做状态控件 Implementation Plan

> 本计划记录首版“内嵌状态格”的实现过程。后续按用户确认的 B 方案调整为紧凑分段轨道：总宽 `240 pt`、总高 `32 pt`，状态圆点在文字左侧，选中实心、未选中空心；现行验收以 `docs/ui/task-macos-ui-spec.md` 为准。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将正在做任务卡的三态状态控件重做为与应用整体一致的内嵌状态格，分离状态标记和文字，且不改变状态持久化。

**Architecture:** `FocusStatePresentation` 与 `FocusPoolPresentation` 提供可测试的尺寸和样式契约；`FocusStateSegmentedControl` 只渲染这些契约并继续通过现有绑定写入 `TaskFocusState`。不修改 SwiftData、仓储或任务领域模型。

**Tech Stack:** SwiftUI、XCTest、macOS 14+

---

### Task 1: Lock the inset-cell presentation contract

**Files:**
- Modify: `Tests/TaskAppTests/FocusPoolPresentationTests.swift`
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift:58-76`

- [x] **Step 1: Write the failing presentation test**

Add this test after `testFocusPoolUsesSharedPageAndCompactControlSizes`:

```swift
func testFocusStatusControlUsesNeutralInsetCellsWithSeparateMarkers() {
    XCTAssertEqual(FocusPoolPresentation.statusControlWidth, 270)
    XCTAssertEqual(FocusPoolPresentation.statusSegmentWidth, 90)
    XCTAssertEqual(FocusPoolPresentation.statusSegmentHeight, 48)
    XCTAssertEqual(FocusPoolPresentation.selectedStatusMarkerSize, 10)
    XCTAssertEqual(FocusPoolPresentation.unselectedStatusMarkerSize, 8)
    XCTAssertTrue(FocusPoolPresentation.statusControlUsesNeutralSurface)
    XCTAssertTrue(FocusPoolPresentation.statusControlSeparatesMarkerAndTitle)
    XCTAssertFalse(FocusPoolPresentation.statusControlUsesFilledStateBackground)
}
```

- [x] **Step 2: Verify RED**

Run:

```bash
swift test --filter FocusPoolPresentationTests/testFocusStatusControlUsesNeutralInsetCellsWithSeparateMarkers
```

Expected: compilation fails because the six new presentation constants do not exist.

- [x] **Step 3: Add the minimal presentation constants**

In `FocusPoolPresentation`, add these declarations after `statusControlFontSize`:

```swift
static let statusSegmentHeight: CGFloat = 48
static let selectedStatusMarkerSize: CGFloat = 10
static let unselectedStatusMarkerSize: CGFloat = 8
static let statusControlUsesNeutralSurface = true
static let statusControlSeparatesMarkerAndTitle = true
static let statusControlUsesFilledStateBackground = false
```

- [x] **Step 4: Verify GREEN**

Run the command from Step 2.

Expected: the selected test passes with zero failures.

### Task 2: Render the approved inset status cells

**Files:**
- Modify: `Sources/TaskApp/Features/FocusPoolScreen.swift:131-175`
- Modify: `docs/ui/task-macos-ui-spec.md:244-249`

- [x] **Step 1: Replace the full-color segmented renderer**

Replace the outer background and `segmentLabel` implementation in `FocusStateSegmentedControl` with a three-cell `HStack(spacing: 0)`. Each button keeps the existing binding and accessibility values. Zero spacing preserves the approved total width of `270 pt` for three `90 pt` cells. Its label must be:

```swift
VStack(spacing: 5) {
    statusMarker(for: state, isSelected: isSelected)
    Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(isSelected ? TaskDesignTokens.ink : TaskDesignTokens.muted)
}
.frame(
    width: FocusPoolPresentation.statusSegmentWidth,
    height: FocusPoolPresentation.statusSegmentHeight
)
.background {
    if isSelected {
        RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
            .fill(TaskDesignTokens.raised)
            .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
    }
}
.overlay {
    if isSelected {
        RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
            .stroke(FocusStatePresentation.selectionColor(for: state).opacity(0.32), lineWidth: 1)
    }
}
```

Add a private `statusMarker(for:isSelected:)` that renders the semantic color as a `10 pt` stroked circle with a low-opacity outer ring when selected, or an `8 pt` filled circle when unselected. The whole status cell remains the button hit target; add no custom animation.

- [x] **Step 2: Update the UI specification**

Append these lines in `docs/ui/task-macos-ui-spec.md` under “5.4 正在做状态”:

```markdown
- 状态控件使用三个内嵌状态格，图标标记位于状态文字上方；每项宽 `90 pt`、最小高 `48 pt`。
- 未选中项为透明底，选中项使用白色 raised surface、低对比状态色描边和极弱阴影；不得使用整块绿、黄、红填充。
```

- [x] **Step 3: Verify focused behavior**

Run:

```bash
swift test --filter FocusPoolPresentationTests
swift build
```

Expected: all focused presentation tests and debug build pass.

### Task 3: Validate the package and commit

**Files:**
- Modify only the files named in Tasks 1 and 2.

- [x] **Step 1: Run project quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
git diff --check
```

Expected: 154 or more tests pass with zero failures; build, package and signature commands exit 0; obsolete-range scan and whitespace check have no output.

- [x] **Step 2: Commit the implementation**

```bash
git add Sources/TaskApp/Features/FocusPoolScreen.swift Tests/TaskAppTests/FocusPoolPresentationTests.swift docs/ui/task-macos-ui-spec.md docs/superpowers/plans/2026-08-06-focus-status-control.md
git commit -m "feat: redesign focus status control"
```

Expected: one focused commit contains the control, its presentation contract test, UI specification update and completed implementation plan.
