# Task Editor Autosave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让任务编辑器在没有保存按钮的情况下自动持久化全部任务字段，并直接关闭编辑器。

**Architecture:** 继续由 `TaskEditorModel` 决定新建或更新，由 `TaskRepository` 负责 SwiftData 写入；`TaskEditorSheet` 只负责监听草稿变化、调度 `250 ms` 防抖和关闭前 flush。自动保存决策通过 `TaskEditorModel.autoSave(using:)` 测试，避免把领域持久化逻辑塞进 View。

**Tech Stack:** SwiftUI、SwiftData、TaskPersistence、XCTest、macOS 14+

---

### Task 1: Add failing autosave and layout tests

**Files:**

- Create: `Tests/TaskAppTests/TaskEditorAutoSaveTests.swift`
- Modify: `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift`

- [ ] **Step 1: Add behavior tests**

Cover these real persistence behaviors with an in-memory `ModelContainer`: an empty new draft creates no task; the first valid title creates exactly one task; later draft changes update that same task; an existing task is updated in place.

- [ ] **Step 2: Add UI contract assertions**

Assert `TaskEditorLayout.usesAutomaticSave` is true and both `showsSaveButton` and `showsCancelButton` are false.

- [ ] **Step 3: Run the focused tests and verify the expected RED failure**

```bash
swift test --filter TaskEditorAutoSaveTests
swift test --filter TaskEditorTitleMetricsTests
```

Expected: compilation fails because the autosave method and layout declarations do not exist yet.

### Task 2: Implement model-level autosave decision

**Files:**

- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorModel.swift`

- [ ] **Step 1: Remove dirty-state-only fields**

Remove `original`, `isDirty`, and `showDiscardConfirmation`; make `existing` mutable so the first new-task save can attach its `TaskItem`.

- [ ] **Step 2: Add minimal autosave behavior**

Add `autoSave(using:)` that returns without writing for a blank title, calls `saveNewTask` once for a new draft, stores the returned item, and calls `updateTask` for later changes or existing tasks.

- [ ] **Step 3: Add layout contracts and run focused tests**

Add the three layout constants and run the tests from Task 1. Expected: all focused tests pass.

### Task 3: Wire debounced autosave and direct dismissal

**Files:**

- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift`

- [ ] **Step 1: Schedule one cancellable save after draft changes**

Use a single `Swift.Task<Void, Never>` stored by the sheet. Cancel the previous task, wait `250 ms`, then call the model autosave method; surface errors through the existing error alert.

- [ ] **Step 2: Flush before closing**

Cancel the pending task, persist the current draft synchronously, and dismiss only when persistence succeeds or there is no persistable title.

- [ ] **Step 3: Remove save/cancel UI and dirty confirmation**

Delete the footer, save keyboard hint, save button, cancel button, and confirmation dialog. Keep only the top-right close button.

- [ ] **Step 4: Preserve completion editing**

Move the completion toggle into the inline metadata area so it remains an automatically saved task field.

### Task 4: Verify, review, and commit the implementation

**Files:**

- Verify changed source and tests only; preserve existing unrelated worktree changes.

- [ ] **Step 1: Run focused tests after each implementation slice**

```bash
swift test --filter TaskEditorAutoSaveTests
swift test --filter TaskEditorTitleMetricsTests
```

- [ ] **Step 2: Run project quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

Expected: tests, build, packaging, and signature verification exit 0; the obsolete-range scan prints no production matches.

- [ ] **Step 3: Review the final diff**

Check correctness, architecture, error handling, write frequency, and scope. Ensure no API key or unrelated file is changed.

- [ ] **Step 4: Commit the implementation**

```bash
git add Sources/TaskApp/Features/TaskEditor Tests/TaskAppTests/TaskEditorAutoSaveTests.swift Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift docs/superpowers/plans/2026-07-16-task-editor-autosave.md
git commit -m "feat: autosave task editor changes"
```
