# Task Dual-Mode Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an autosaving quick task editor and an isolated, explicitly saved Markdown writing surface that match the approved 2026-07-16 task-editor design.

**Architecture:** Keep metadata in `TaskEditorModel` and persist it through the existing repository debounce. Add `MarkdownDraftSession` as a separate in-memory state machine; only it can save `TaskItem.details` through a narrow repository method. `TaskEditorOverlay` owns the model and switches between Quick and Markdown surfaces without recreating the metadata draft.

**Tech Stack:** SwiftUI, AppKit `NSTextView` bridge, SwiftData, XCTest, macOS 14+

---

### Task 1: Isolate Markdown persistence with tests

**Files:**
- Create: `Tests/TaskAppTests/MarkdownDraftSessionTests.swift`
- Modify: `Tests/TaskAppTests/TaskEditorAutoSaveTests.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorModel.swift`
- Modify: `Sources/TaskPersistence/TaskRepository.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownDraftSession.swift`

- [ ] **Step 1: Write failing session tests**

```swift
func testCancelRestoresOpeningDetails() {
    let session = MarkdownDraftSession(details: "before")
    session.details = "after"
    session.cancel()
    XCTAssertEqual(session.details, "before")
    XCTAssertFalse(session.isDirty)
}

func testSaveUpdatesOnlyDetails() throws {
    let item = try makeTask(title: "Keep title", details: "before")
    let session = MarkdownDraftSession(details: item.details)
    session.details = "# after"
    try session.save(using: repository, for: item)
    XCTAssertEqual(item.details, "# after")
    XCTAssertEqual(item.title, "Keep title")
}
```

- [ ] **Step 2: Verify red**

Run: `swift test --filter MarkdownDraftSessionTests`

Expected: compilation failure for `MarkdownDraftSession` and `updateDetails`.

- [ ] **Step 3: Implement the narrow details update path**

```swift
public func updateDetails(_ item: TaskItem, details: String) throws {
    item.details = details
    item.updatedAt = .now
    try context.save()
}
```

`TaskEditorModel.autoSave(using:)` must preserve `existing.details` during metadata saves. Add `acceptSavedDetails(_:)` to synchronise a successful Markdown save back into its draft without starting a new details write.

- [ ] **Step 4: Verify green and commit**

Run: `swift test --filter 'MarkdownDraftSessionTests|TaskEditorAutoSaveTests'`

Commit: `test: isolate markdown task details persistence`

### Task 2: Make Markdown formatting deterministic

**Files:**
- Create: `Tests/TaskAppTests/MarkdownFormattingTests.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownFormatting.swift`

- [ ] **Step 1: Write failing transformation tests**

```swift
func testBoldWrapsSelectionAndMovesCaretInsideMarkers() {
    XCTAssertEqual(
        MarkdownFormatting.apply(.bold, to: "word", selection: NSRange(location: 0, length: 4)).text,
        "**word**"
    )
}

func testHeadingPrefixesEverySelectedLine() {
    XCTAssertEqual(
        MarkdownFormatting.apply(.heading, to: "one\ntwo", selection: NSRange(location: 0, length: 7)).text,
        "# one\n# two"
    )
}
```

- [ ] **Step 2: Verify red**

Run: `swift test --filter MarkdownFormattingTests`

Expected: compilation failure because `MarkdownFormatting` does not exist.

- [ ] **Step 3: Implement supported commands**

Define `MarkdownCommand` for bold, italic, heading, unorderedList, orderedList, taskList, link, image, table, quote, strikethrough, undo and redo. Return text plus selection from a pure `MarkdownFormatting.apply`; commands that need native history return a no-op transform and are sent to `NSTextView`.

- [ ] **Step 4: Verify green and commit**

Run: `swift test --filter MarkdownFormattingTests`

Commit: `feat: add markdown formatting transforms`

### Task 3: Build the Markdown writing surface

**Files:**
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownTextEditor.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownPreview.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownFormattingToolbar.swift`
- Create: `Sources/TaskApp/Features/TaskEditor/MarkdownTaskEditor.swift`
- Create: `Tests/TaskAppTests/MarkdownEditorPresentationTests.swift`

- [ ] **Step 1: Write failing presentation contract tests**

```swift
func testMarkdownEditorUsesExplicitSaveAndTwoPanes() {
    XCTAssertTrue(MarkdownEditorLayout.usesExplicitSave)
    XCTAssertEqual(MarkdownEditorLayout.paneCount, 2)
}
```

- [ ] **Step 2: Implement focused UI components**

`MarkdownTextEditor` bridges `NSTextView` so toolbar commands apply to the live selection and participate in native undo/redo. `MarkdownPreview` renders `AttributedString(markdown:)`, falling back to literal text for malformed input. `MarkdownTaskEditor` presents the toolbar, equal width panes, live word count, `Command-S`, confirm, cancel and Escape handlers.

- [ ] **Step 3: Wire session outcomes**

The save closure calls `MarkdownDraftSession.save`, then `TaskEditorModel.acceptSavedDetails`; cancel calls `session.cancel` and returns without repository access. A save error remains on the editor and presents an alert.

- [ ] **Step 4: Verify and commit**

Run: `swift test --filter 'MarkdownEditorPresentationTests|MarkdownDraftSessionTests'`

Commit: `feat: add explicit markdown task editor`

### Task 4: Convert the overlay into a two-surface editor flow

**Files:**
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/SubtaskEditor.swift`
- Modify: `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift`

- [ ] **Step 1: Write failing contracts**

```swift
func testQuickEditorKeepsAutomaticMetadataSaving() {
    XCTAssertTrue(TaskEditorLayout.usesAutomaticSave)
    XCTAssertTrue(TaskEditorLayout.opensMarkdownEditorForDetails)
}
```

- [ ] **Step 2: Implement the flow**

Move `TaskEditorModel` ownership into `TaskEditorOverlay`. It renders the dimmed adaptive quick editor or the full-window Markdown editor using a single route enum. The quick editor replaces its `TextEditor` with an accessible rendered Markdown summary row. Opening Markdown first flushes a persistable title and metadata; closing quick editor flushes the pending metadata task. The subtask input uses `Control-Return` to add and keeps Return for native text editing.

- [ ] **Step 3: Verify and commit**

Run: `swift test --filter 'TaskEditor|Markdown'`

Commit: `feat: connect quick and markdown task editing`

### Task 5: Add in-lane quick creation

**Files:**
- Modify: `Sources/TaskApp/Features/Board/BoardColumnView.swift`
- Modify: `Sources/TaskApp/Features/TaskList/TaskListScreen.swift`
- Modify: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`
- Create: `Tests/TaskAppTests/InlineTaskCreationTests.swift`

- [ ] **Step 1: Write failing creation tests**

```swift
func testWhitespaceTitleDoesNotCreateTask() throws { /* repository remains empty */ }
func testControlReturnCreatesTaskInSelectedColumn() throws { /* one task has column id */ }
```

- [ ] **Step 2: Implement `InlineTaskCreationRow`**

Use a stable-height title input below a lane. `Control-Return` invokes a screen-owned repository closure, clears after a successful write, and retains focus for subsequent tasks. Board and local-task lanes pass their exact `BoardColumn.id` into `TaskDraft`.

- [ ] **Step 3: Verify and commit**

Run: `swift test --filter InlineTaskCreationTests`

Commit: `feat: add inline lane task creation`

### Task 6: Validate, package, and inspect the running app

**Files:** all changed source and tests; update this plan checkbox state only after checks pass.

- [ ] **Step 1: Run required quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

- [ ] **Step 2: Run the packaged app**

Open `dist/Task.app`, inspect new task, quick metadata autosave, Markdown save/cancel, toolbar commands, keyboard paths, dark mode and Reduce Motion.

- [ ] **Step 3: Commit validation state**

Commit: `docs: complete dual-mode editor plan`
