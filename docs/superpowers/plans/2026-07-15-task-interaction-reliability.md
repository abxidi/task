# Task 交互可靠性与状态栏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让看板跨泳道拖动连续稳定，并提供可配置的全局唤起快捷键和直接激活主窗口的状态栏入口。

**Architecture:** 看板手势状态隔离在 `BoardDragCoordinator`，只在完成手势时调用现有 workflow service。快捷键的纯配置/状态机与 AppKit/Carbon 桥接分离；状态栏和快捷键均通过同一个 `TaskWindowActivator` 唤起现有窗口。

**Tech Stack:** SwiftUI、AppKit、Carbon、XCTest、macOS 14+

---

## 文件职责

- `Sources/TaskApp/Features/Board/BoardDragCoordinator.swift`：可测试的看板拖动会话状态。
- `Sources/TaskApp/Features/Board/BoardColumnView.swift`：卡片手势、源占位和目标描边。
- `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`：泳道 frame、拖动浮层和持久化提交。
- `Sources/TaskApp/App/GlobalShortcut*.swift`：快捷键值类型、检测器、注册器与生命周期。
- `Sources/TaskApp/App/TaskWindowActivator.swift`：唯一的主窗口激活路径。
- `Sources/TaskApp/App/StatusBarController.swift`：状态栏项和模板图标。
- `Sources/TaskApp/Features/Settings/SettingsScreen.swift`：快捷键设置界面。

### Task 1: 建立看板拖动会话

**Files:**
- Create: `Sources/TaskApp/Features/Board/BoardDragCoordinator.swift`
- Modify: `Tests/TaskAppTests/BoardDragPresentationTests.swift`

- [ ] **Step 1: 写入失败测试并确认失败**

```swift
@MainActor
func testFinishingDragMovesOnlyToAnotherLaneAndClearsSession() {
    let source = UUID(); let target = UUID(); let task = UUID()
    let coordinator = BoardDragCoordinator()
    coordinator.begin(taskID: task, sourceColumnID: source, location: .zero)
    coordinator.update(location: CGPoint(x: 120, y: 80), targetColumnID: target)
    XCTAssertEqual(coordinator.finish(), .init(taskID: task, targetColumnID: target))
    XCTAssertNil(coordinator.taskID)
}
```

Run: `swift test --filter BoardDragPresentationTests`

Expected: FAIL because `BoardDragCoordinator` and `BoardDragMove` do not exist.

- [ ] **Step 2: 实现最小协调器**

```swift
@MainActor
final class BoardDragCoordinator: ObservableObject {
    @Published private(set) var taskID: UUID?
    @Published private(set) var sourceColumnID: UUID?
    @Published private(set) var targetColumnID: UUID?
    @Published private(set) var location: CGPoint?
    func begin(taskID: UUID, sourceColumnID: UUID, location: CGPoint) {
        self.taskID = taskID
        self.sourceColumnID = sourceColumnID
        self.targetColumnID = sourceColumnID
        self.location = location
    }
    func update(location: CGPoint, targetColumnID: UUID?) {
        self.location = location
        self.targetColumnID = targetColumnID
    }
    func finish() -> BoardDragMove? {
        defer { cancel() }
        guard let taskID, let sourceColumnID, let targetColumnID,
              sourceColumnID != targetColumnID else { return nil }
        return .init(taskID: taskID, targetColumnID: targetColumnID)
    }
    func cancel() {
        taskID = nil
        sourceColumnID = nil
        targetColumnID = nil
        location = nil
    }
}
```

- [ ] **Step 3: 验证并提交**

Run: `swift test --filter BoardDragPresentationTests`

Expected: PASS.

```bash
git add Sources/TaskApp/Features/Board/BoardDragCoordinator.swift Tests/TaskAppTests/BoardDragPresentationTests.swift
git commit -m "fix: coordinate board lane dragging"
```

### Task 2: 用本地手势渲染跨泳道拖动

**Files:**
- Modify: `Sources/TaskApp/Features/Board/BoardColumnView.swift`
- Modify: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`
- Modify: `Tests/TaskAppTests/BoardDragPresentationTests.swift`

- [ ] **Step 1: 写入失败展示测试**

```swift
func testActiveSourceUsesPlaceholderOpacityInsteadOfBeingHidden() {
    XCTAssertEqual(BoardDragPresentation.sourceOpacity(isActiveSource: true), 0.35)
    XCTAssertEqual(BoardDragPresentation.sourceOpacity(isActiveSource: false), 1)
}
```

Run: `swift test --filter BoardDragPresentationTests`

Expected: FAIL because the presentation API does not expose placeholder opacity.

- [ ] **Step 2: 接入手势和浮层**

`BoardColumnView` 接收共享 coordinator 和 `onDragChanged` / `onDragEnded` closure。卡片使用 `DragGesture(minimumDistance: 3, coordinateSpace: .global)`，不再使用 `onDrag` 或 `dropDestination`。`ProjectBoardScreen` 用 `GeometryReader` 收集固定宽度泳道的全局 frame，在 `onChanged` 中解析目标泳道，在根 overlay 中以 `BoardTaskCard` 渲染固定宽度 `248 pt` 的活动浮层；源卡片 opacity 为 `0.35`。

- [ ] **Step 3: 在结束手势时调用现有持久化路径并验证**

只有 `coordinator.finish()` 返回跨泳道 `BoardDragMove` 时调用 `move(_:to:project:)`。同泳道松手与取消不写入数据。

Run: `swift test --filter BoardDragPresentationTests && swift test --filter BoardWorkflowServiceTests`

Expected: PASS.

```bash
git add Sources/TaskApp/Features/Board/BoardColumnView.swift Sources/TaskApp/Features/Board/ProjectBoardScreen.swift Tests/TaskAppTests/BoardDragPresentationTests.swift
git commit -m "fix: keep board lane dragging continuous"
```

### Task 3: 实现全局快捷键领域状态

**Files:**
- Create: `Sources/TaskApp/App/GlobalShortcutConfiguration.swift`
- Create: `Sources/TaskApp/App/DoubleControlDetector.swift`
- Create: `Tests/TaskAppTests/GlobalShortcutConfigurationTests.swift`

- [ ] **Step 1: 写入失败测试**

```swift
func testDoubleControlTriggersOnlyAfterTwoReleasedControlsWithinWindow() {
    var detector = DoubleControlDetector()
    XCTAssertFalse(detector.handle(.controlDown, at: 0))
    XCTAssertFalse(detector.handle(.controlUp, at: 0.05))
    XCTAssertFalse(detector.handle(.controlDown, at: 0.20))
    XCTAssertTrue(detector.handle(.controlUp, at: 0.25))
}
```

另外覆盖超时、夹杂其他键、默认配置、Codable 自定义组合键和停用模式。

Run: `swift test --filter GlobalShortcutConfigurationTests`

Expected: FAIL because the configuration and detector do not exist.

- [ ] **Step 2: 实现配置和检测器**

定义 `GlobalShortcutMode`（`.doubleControl`、`.custom`、`.disabled`）、`GlobalShortcutConfiguration` 和 `DoubleControlDetector.Event`。检测器只根据事件和单调时间戳更新状态，不引用 `NSEvent`。

- [ ] **Step 3: 验证并提交**

Run: `swift test --filter GlobalShortcutConfigurationTests`

Expected: PASS.

```bash
git add Sources/TaskApp/App/GlobalShortcutConfiguration.swift Sources/TaskApp/App/DoubleControlDetector.swift Tests/TaskAppTests/GlobalShortcutConfigurationTests.swift
git commit -m "feat: model global shortcut behavior"
```

### Task 4: 注册快捷键并提供设置入口

**Files:**
- Create: `Sources/TaskApp/App/GlobalShortcutManager.swift`
- Create: `Sources/TaskApp/App/TaskWindowActivator.swift`
- Modify: `Sources/TaskApp/App/TaskApplication.swift`
- Modify: `Sources/TaskApp/Features/Settings/SettingsScreen.swift`
- Create: `Tests/TaskAppTests/GlobalShortcutManagerTests.swift`

- [ ] **Step 1: 写入失败注册测试**

用假 registrar 验证注册新自定义组合键失败后，manager 保留 `activeConfiguration`；用假 activation handler 验证触发事件只调用窗口激活器一次。

Run: `swift test --filter GlobalShortcutManagerTests`

Expected: FAIL because manager protocol and window activator do not exist.

- [ ] **Step 2: 实现最小 AppKit/Carbon bridge**

`GlobalShortcutManager` 在双击模式安装只观察的 `NSEvent.addGlobalMonitorForEvents`，在自定义模式经 `RegisterEventHotKey` 注册。它使用 `CGPreflightListenEventAccess()` 公开权限状态，并仅在注册成功后写入 `UserDefaults`。`TaskWindowActivator.showMainWindow()` 调用 `NSApp.unhide(nil)`、`activate(ignoringOtherApps: true)` 和已有窗口的 `makeKeyAndOrderFront(nil)`。

设置使用 `Form` 分段控件、快捷键录入控件、无权限时的行内说明及“打开系统设置”按钮。所有图标控件设置 accessibility label。

- [ ] **Step 3: 验证并提交**

Run: `swift test --filter GlobalShortcutManagerTests && swift build`

Expected: PASS.

```bash
git add Sources/TaskApp/App Sources/TaskApp/Features/Settings/SettingsScreen.swift Tests/TaskAppTests/GlobalShortcutManagerTests.swift
git commit -m "feat: add configurable global task activation"
```

### Task 5: 增加状态栏主窗口入口

**Files:**
- Create: `Sources/TaskApp/App/StatusBarController.swift`
- Modify: `Sources/TaskApp/App/TaskApplication.swift`
- Create: `Tests/TaskAppTests/StatusBarControllerTests.swift`

- [ ] **Step 1: 写入失败测试**

```swift
@MainActor
func testStatusItemActivationUsesSharedWindowActivator() {
    var activations = 0
    let controller = StatusBarController { activations += 1 }
    controller.activateMainWindow(nil)
    XCTAssertEqual(activations, 1)
}
```

Run: `swift test --filter StatusBarControllerTests`

Expected: FAIL because `StatusBarController` does not exist.

- [ ] **Step 2: 实现模板图标和状态栏控制器**

用 `NSImage`/Core Graphics 创建与用户素材一致的圆角方形 alpha 蒙版，并从蒙版中清除 `T`；设定 `isTemplate = true`。`NSStatusItem.button` 的 action 指向 `activateMainWindow(_:)`，可访问性标签为“显示 Task 主窗口”。在 `TaskApplication` 持有 controller，使用 `TaskWindowActivator.showMainWindow` 作为 action。

- [ ] **Step 3: 验证并提交**

Run: `swift test --filter StatusBarControllerTests && swift build`

Expected: PASS.

```bash
git add Sources/TaskApp/App/StatusBarController.swift Sources/TaskApp/App/TaskApplication.swift Tests/TaskAppTests/StatusBarControllerTests.swift
git commit -m "feat: add status bar task window launcher"
```

### Task 6: 发布级验证

- [ ] **Step 1: 执行项目质量门槛**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\\+5(?![0-9])|11 级|11 个' Sources
```

Expected: 前四个命令 exit 0；最后一个命令在生产源码无输出。

- [ ] **Step 2: 真实 macOS 运行态验收**

启动 `dist/Task.app`，检查不同泳道拖动、双击 `Control`、自定义组合键、未授权提示、状态栏白色镂空 `T`、深色模式和 VoiceOver 标签。记录无法在自动化环境完成的权限/全局输入验证。
