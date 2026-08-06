# Task Editor Adaptive Note Height Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the task editor note field compact for one line, grow from actual wrapped lines through five visible lines, and scroll internally thereafter.

**Architecture:** Put line-height clamping and sheet-size arithmetic in pure TaskApp layout types. A focused AppKit `NSTextView` bridge measures its own layout-manager line fragments, writes the note binding, and reports a clamped height to SwiftUI. `TaskEditorSheet` owns the rendered note height; `TaskEditorOverlay` uses that value only to calculate the presentation size.

**Tech Stack:** SwiftUI, AppKit (`NSTextView`, `NSScrollView`, `NSLayoutManager`), XCTest, macOS 14+

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Sources/TaskApp/Features/TaskEditor/TaskEditorNoteLayout.swift` | Pure constants and functions for visible-line height clamping. |
| `Sources/TaskApp/Features/TaskEditor/AdaptiveNoteTextEditor.swift` | The AppKit-backed editable note field, true line-fragment measurement, internal scrolling, and VoiceOver label. |
| `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift` | Binds `TaskDraft.details`, renders the adaptive field, and reports height changes upward. |
| `Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift` | Includes the current note height when calculating the sheet size. |
| `Tests/TaskAppTests/TaskEditorNoteLayoutTests.swift` | Unit tests for height rules and AppKit layout-based wrapping. |
| `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift` | Regression contracts for overlay height changes and the existing `88%` cap. |

### Task 1: Define the failing adaptive-height contracts

**Files:**
- Create: `Tests/TaskAppTests/TaskEditorNoteLayoutTests.swift`
- Modify: `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift`

- [ ] **Step 1: Write failing note layout tests**

```swift
import AppKit
import XCTest
@testable import TaskApp

final class TaskEditorNoteLayoutTests: XCTestCase {
    func testOneLineAndEmptyNoteUseCompactHeight() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 0), 32)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 1), 32)
    }

    func testNoteHeightGrowsByLineHeightThroughFiveLines() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 2), 52)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 5), 112)
    }

    func testNoteHeightCapsAtFiveVisibleLines() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 6), 112)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 20), 112)
        XCTAssertTrue(TaskEditorNoteLayout.requiresInternalScrolling(forLineCount: 6))
    }

    func testActualLineCounterCountsExplicitLineBreaks() {
        XCTAssertEqual(TaskEditorNoteLineCounter.count(in: "一行\n二行\n三行", width: 460), 3)
    }

    func testActualLineCounterCountsSoftWraps() {
        let text = String(repeating: "任", count: 20)
        XCTAssertGreaterThan(TaskEditorNoteLineCounter.count(in: text, width: 40), 1)
    }
}
```

Add this failing overlay assertion to `TaskEditorTitleMetricsTests`:

```swift
func testEditorHeightIncludesAdditionalVisibleNoteLines() {
    let compact = TaskEditorOverlayLayout.panelSize(
        for: CGSize(width: 1900, height: 1000),
        subtaskCount: 0,
        noteHeight: TaskEditorNoteLayout.minimumHeight
    )
    let fiveLines = TaskEditorOverlayLayout.panelSize(
        for: CGSize(width: 1900, height: 1000),
        subtaskCount: 0,
        noteHeight: TaskEditorNoteLayout.maximumHeight
    )

    XCTAssertEqual(compact.height, 360)
    XCTAssertEqual(fiveLines.height, 440)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter 'TaskEditorNoteLayoutTests|TaskEditorTitleMetricsTests'
```

Expected: compilation fails because `TaskEditorNoteLayout`, `TaskEditorNoteLineCounter`, and the `noteHeight` parameter do not exist.

### Task 2: Implement pure note metrics and overlay sizing

**Files:**
- Create: `Sources/TaskApp/Features/TaskEditor/TaskEditorNoteLayout.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift`

- [ ] **Step 1: Implement layout constants and clamping**

Create `TaskEditorNoteLayout.swift` with the following public-to-module contract:

```swift
import AppKit

enum TaskEditorNoteLayout {
    static let font = NSFont.systemFont(ofSize: 15)
    static let minimumHeight: CGFloat = 32
    static let lineHeight: CGFloat = 20
    static let maximumVisibleLines = 5
    static let maximumHeight = minimumHeight + CGFloat(maximumVisibleLines - 1) * lineHeight

    static func height(forLineCount lineCount: Int) -> CGFloat {
        let visibleLines = min(max(1, lineCount), maximumVisibleLines)
        return minimumHeight + CGFloat(visibleLines - 1) * lineHeight
    }

    static func requiresInternalScrolling(forLineCount lineCount: Int) -> Bool {
        lineCount > maximumVisibleLines
    }
}

enum TaskEditorNoteLineCounter {
    static func count(in text: String, width: CGFloat) -> Int {
        let storage = NSTextStorage(string: text, attributes: [.font: TaskEditorNoteLayout.font])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)

        let glyphRange = manager.glyphRange(for: container)
        var lineCount = 0
        manager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in lineCount += 1 }
        return max(1, lineCount)
    }
}
```

- [ ] **Step 2: Extend overlay sizing without changing the compact baseline**

Change `TaskEditorOverlayLayout.panelSize` to accept a defaulted `noteHeight` and add only the non-compact delta:

```swift
static func panelSize(
    for availableSize: CGSize,
    subtaskCount: Int,
    noteHeight: CGFloat = TaskEditorNoteLayout.minimumHeight
) -> CGSize {
    let noteHeightDelta = max(0, noteHeight - TaskEditorNoteLayout.minimumHeight)
    let desiredHeight = initialHeight
        + noteHeightDelta
        + CGFloat(max(0, subtaskCount)) * subtaskHeightIncrement
    return CGSize(
        width: min(preferredWidth, max(minimumWidth, availableSize.width - edgeInset * 2)),
        height: min(desiredHeight, availableSize.height * maximumHeightRatio)
    )
}
```

Keep the default parameter so existing callers and existing subtask-height tests retain their `360` and `483` expectations.

- [ ] **Step 3: Verify GREEN and commit the isolated layout increment**

Run:

```bash
swift test --filter 'TaskEditorNoteLayoutTests|TaskEditorTitleMetricsTests'
```

Expected: all focused tests pass.

Commit:

```bash
git add Sources/TaskApp/Features/TaskEditor/TaskEditorNoteLayout.swift Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift Tests/TaskAppTests/TaskEditorNoteLayoutTests.swift Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift
git commit -m "feat: add adaptive task note layout"
```

### Task 3: Bridge a measured, internally scrolling native note editor

**Files:**
- Create: `Sources/TaskApp/Features/TaskEditor/AdaptiveNoteTextEditor.swift`
- Modify: `Tests/TaskAppTests/TaskEditorNoteLayoutTests.swift`

- [ ] **Step 1: Add the failing bridge presentation contracts**

Append these assertions to `TaskEditorNoteLayoutTests`:

```swift
func testAdaptiveNoteEditorUsesActualTextLayoutAndInternalScrolling() {
    XCTAssertTrue(AdaptiveNoteTextEditorLayout.measuresActualLineFragments)
    XCTAssertTrue(AdaptiveNoteTextEditorLayout.usesInternalScrolling)
    XCTAssertEqual(AdaptiveNoteTextEditorLayout.accessibilityLabel, "任务备注")
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter TaskEditorNoteLayoutTests
```

Expected: compilation fails because `AdaptiveNoteTextEditorLayout` does not exist.

- [ ] **Step 3: Implement `AdaptiveNoteTextEditor`**

Create a `NSViewRepresentable` with this surface:

```swift
struct AdaptiveNoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onHeightChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSScrollView
    func updateNSView(_ scrollView: NSScrollView, context: Context)
    func makeCoordinator() -> Coordinator
}

enum AdaptiveNoteTextEditorLayout {
    static let measuresActualLineFragments = true
    static let usesInternalScrolling = true
    static let accessibilityLabel = "任务备注"
}
```

In `makeNSView`, configure a transparent `NSScrollView` with `TaskScrollIndicatorStyle.configure`, a vertically resizable `NSTextView`, `TaskEditorNoteLayout.font`, `NSColor(TaskDesignTokens.muted)`, `isRichText = false`, and `allowsUndo = true`. Set `textContainer.lineFragmentPadding = 0`, `textContainerInset = NSSize(width: 5, height: 7)`, `widthTracksTextView = true`, `heightTracksTextView = false`, and `accessibilityLabel` to the layout label.

The coordinator is the `NSTextViewDelegate`. In `textDidChange`, assign `parent.text = textView.string`, then call its measurement method. In `textDidBeginEditing` and `textDidEndEditing`, synchronise the `isFocused` binding. To measure, obtain the text container's glyph range from its live `layoutManager`, enumerate its line fragments, call `TaskEditorNoteLayout.height(forLineCount:)`, and dispatch `onHeightChange` asynchronously on the main queue. A small `NSScrollView` subclass calls the same measurement closure from `layout()` so width changes recalculate soft wrapping. Keep the document view vertically resizable so content beyond the five-line frame scrolls without changing the reported height.

In `updateNSView`, only overwrite `textView.string` when it differs from the bound value; always schedule a fresh measurement after the scroll view receives its SwiftUI width.

- [ ] **Step 4: Verify GREEN and commit the bridge**

Run:

```bash
swift test --filter TaskEditorNoteLayoutTests
```

Expected: all note layout and bridge contracts pass.

Commit:

```bash
git add Sources/TaskApp/Features/TaskEditor/AdaptiveNoteTextEditor.swift Tests/TaskAppTests/TaskEditorNoteLayoutTests.swift
git commit -m "feat: measure task note editor height"
```

### Task 4: Wire the adaptive field into the task editor

**Files:**
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift`
- Modify: `Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift`
- Modify: `Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift`

- [ ] **Step 1: Add the failing quick-editor contract**

Add this test to `TaskEditorTitleMetricsTests`:

```swift
func testQuickEditorUsesAnAdaptiveNoteInsteadOfFocusDrivenExpansion() {
    XCTAssertTrue(TaskEditorLayout.usesAdaptiveNoteHeight)
    XCTAssertEqual(TaskEditorLayout.noteMinimumHeight, 32)
    XCTAssertEqual(TaskEditorLayout.noteMaximumHeight, 112)
    XCTAssertFalse(TaskEditorLayout.expandsNoteOnlyForFocus)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter TaskEditorTitleMetricsTests
```

Expected: compilation fails because the adaptive-note layout properties do not exist.

- [ ] **Step 3: Replace the fixed `TextEditor` with the adaptive editor**

In `TaskEditorOverlay`, add `@State private var noteHeight = TaskEditorNoteLayout.minimumHeight`, pass it to `panelSize`, and pass a `onNoteHeightChange` closure into `TaskEditorSheet` that updates the state only when the new value differs.

In `TaskEditorSheet`, add `@State private var noteHeight = TaskEditorNoteLayout.minimumHeight` and an `onNoteHeightChange` initializer closure. Replace the existing `TextEditor` ZStack and `.frame(height: isDescriptionExpanded ? 142 : 48)` with:

```swift
ZStack(alignment: .topLeading) {
    if TaskEditorPlaceholder.isVisible(text: model.draft.details, isFocused: descriptionFocused) {
        Text("添加备注...")
            .font(.system(size: 15))
            .foregroundStyle(TaskDesignTokens.quiet.opacity(TaskEditorPlaceholder.opacity))
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
            .allowsHitTesting(false)
    }
    AdaptiveNoteTextEditor(
        text: $model.draft.details,
        isFocused: $descriptionFocused
    ) { measuredHeight in
        guard noteHeight != measuredHeight else { return }
        noteHeight = measuredHeight
        onNoteHeightChange(measuredHeight)
    }
}
.frame(height: noteHeight)
.padding(.top, 14)
```

Pass `isFocused: $descriptionFocused` to `AdaptiveNoteTextEditor`; do not apply SwiftUI's `.focused` modifier to the AppKit bridge. Remove the surrounding description `.contentShape` and `.onTapGesture` so native text-selection and input events remain owned by `NSTextView`. Remove `isDescriptionExpanded`; it must not be replaced with any focus-driven height calculation. Preserve the existing `model.draft` observer so the 250 ms autosave behavior is unchanged. Add these values to `TaskEditorLayout`:

```swift
static let usesAdaptiveNoteHeight = true
static let expandsNoteOnlyForFocus = false
static let noteMinimumHeight = TaskEditorNoteLayout.minimumHeight
static let noteMaximumHeight = TaskEditorNoteLayout.maximumHeight
```

- [ ] **Step 4: Verify editor integration and commit**

Run:

```bash
swift test --filter 'TaskEditorNoteLayoutTests|TaskEditorTitleMetricsTests|TaskEditorAutoSaveTests'
```

Expected: all focused tests pass, including existing auto-save coverage for `TaskDraft.details`.

Commit:

```bash
git add Sources/TaskApp/Features/TaskEditor/TaskEditorSheet.swift Sources/TaskApp/Features/TaskEditor/TaskEditorOverlay.swift Tests/TaskAppTests/TaskEditorTitleMetricsTests.swift
git commit -m "feat: grow task note editor by line count"
```

### Task 5: Run release validation and inspect the running app

**Files:**
- Verify: changed TaskEditor source and tests only

- [ ] **Step 1: Run the full required quality gates**

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

Expected: every command exits `0`; the final scan prints no production-source matches.

- [ ] **Step 2: Perform the macOS runtime acceptance check**

Open `dist/Task.app` after quitting any older running copy. In both light and dark modes, verify: an empty note, a one-line URL, explicit Chinese line breaks, a long soft-wrapped URL, pasted content over five lines, an editor width change, VoiceOver's “任务备注” label, automatic save after `250 ms`, and no overlap with subtasks or metadata. Confirm the parent sheet grows to five lines only and remains within `88%` of the available window height.

- [ ] **Step 3: Review the final diff and commit validation state**

Run:

```bash
git diff --check
git status --short
```

Confirm no SwiftData model, persistence repository, Markdown editor, API key path, or unrelated file changed. Commit only if a validation artifact is intentionally added; otherwise leave the three feature commits as the completed implementation history.
