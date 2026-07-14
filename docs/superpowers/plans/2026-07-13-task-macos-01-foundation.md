# Task macOS 01 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立可启动、可测试、可持久化并可打包为 `Task.app` 的原生 macOS 基础工程。

**Architecture:** 使用 Swift Package 拆分 `TaskDomain`、`TaskPersistence`、`TaskAI`、`TaskNotifications` 和 `TaskApp`。领域层只依赖 Foundation；SwiftData 和 SwiftUI 位于外层，保证优先级规则可独立测试。

**Tech Stack:** Swift 5.9+、SwiftUI、SwiftData、Swift Package Manager、XCTest、macOS 14+

---

## 前置条件

先阅读：

- `AGENTS.md`
- `docs/superpowers/specs/2026-07-13-task-macos-design.md`
- `docs/ui/task-macos-ui-spec.md`

验证环境：

```bash
xcode-select -p
swift --version
git status --short
```

预期：Xcode 路径存在；Swift 版本至少 5.9；工作区没有未理解的修改。

## 文件结构

本计划创建：

```text
Package.swift
Packaging/Info.plist
Sources/TaskDomain/PriorityCoordinate.swift
Sources/TaskDomain/PriorityQuadrant.swift
Sources/TaskDomain/UrgencyPalette.swift
Sources/TaskDomain/TaskDomainModule.swift
Sources/TaskPersistence/TaskPersistenceModule.swift
Sources/TaskApp/TaskAppModule.swift
Sources/TaskPersistence/Models/TaskItem.swift
Sources/TaskPersistence/Models/Subtask.swift
Sources/TaskPersistence/Models/Project.swift
Sources/TaskPersistence/Models/BoardColumn.swift
Sources/TaskPersistence/Models/Tag.swift
Sources/TaskPersistence/ModelContainerFactory.swift
Sources/TaskPersistence/TaskRepository.swift
Sources/TaskAI/TaskAIModule.swift
Sources/TaskNotifications/TaskNotificationsModule.swift
Sources/TaskApp/App/TaskApplication.swift
Sources/TaskApp/App/AppRoute.swift
Sources/TaskApp/App/TaskAppShell.swift
Sources/TaskApp/Resources/Assets.xcassets/Contents.json
Tests/TaskDomainTests/PriorityCoordinateTests.swift
Tests/TaskDomainTests/UrgencyPaletteTests.swift
Tests/TaskPersistenceTests/TaskRepositoryTests.swift
Tests/TaskDomainTests/ModuleSmokeTests.swift
Tests/TaskPersistenceTests/ModuleSmokeTests.swift
Tests/TaskAITests/ModuleSmokeTests.swift
Tests/TaskNotificationsTests/ModuleSmokeTests.swift
scripts/package_app.sh
```

### Task 1: Scaffold the Swift package

**Files:**

- Create: `Package.swift`
- Create: `Sources/TaskDomain/TaskDomainModule.swift`
- Create: `Sources/TaskPersistence/TaskPersistenceModule.swift`
- Create: `Sources/TaskAI/TaskAIModule.swift`
- Create: `Sources/TaskNotifications/TaskNotificationsModule.swift`
- Create: `Sources/TaskApp/TaskAppModule.swift`
- Create: `Sources/TaskApp/Resources/Assets.xcassets/Contents.json`
- Create: `Tests/TaskDomainTests/ModuleSmokeTests.swift`
- Create: `Tests/TaskPersistenceTests/ModuleSmokeTests.swift`
- Create: `Tests/TaskAITests/ModuleSmokeTests.swift`
- Create: `Tests/TaskNotificationsTests/ModuleSmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Task",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TaskDomain", targets: ["TaskDomain"]),
        .library(name: "TaskPersistence", targets: ["TaskPersistence"]),
        .library(name: "TaskAI", targets: ["TaskAI"]),
        .library(name: "TaskNotifications", targets: ["TaskNotifications"]),
        .executable(name: "TaskApp", targets: ["TaskApp"]),
    ],
    targets: [
        .target(name: "TaskDomain"),
        .target(name: "TaskPersistence", dependencies: ["TaskDomain"]),
        .target(name: "TaskAI", dependencies: ["TaskDomain"]),
        .target(name: "TaskNotifications", dependencies: ["TaskDomain"]),
        .executableTarget(
            name: "TaskApp",
            dependencies: ["TaskDomain", "TaskPersistence", "TaskAI", "TaskNotifications"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TaskDomainTests", dependencies: ["TaskDomain"]),
        .testTarget(name: "TaskPersistenceTests", dependencies: ["TaskPersistence", "TaskDomain"]),
        .testTarget(name: "TaskAITests", dependencies: ["TaskAI", "TaskDomain"]),
        .testTarget(name: "TaskNotificationsTests", dependencies: ["TaskNotifications", "TaskDomain"]),
    ]
)
```

- [ ] **Step 2: Add compiling module markers**

```swift
// Create one file per path so every package target is non-empty.
// Sources/TaskDomain/TaskDomainModule.swift
public enum TaskDomainModule {}

// Sources/TaskPersistence/TaskPersistenceModule.swift
public enum TaskPersistenceModule {}

// Sources/TaskAI/TaskAIModule.swift
public enum TaskAIModule {}

// Sources/TaskNotifications/TaskNotificationsModule.swift
public enum TaskNotificationsModule {}

// Sources/TaskApp/TaskAppModule.swift
enum TaskAppModule {}
```

Create one smoke test in each declared test target so SwiftPM never sees an empty target:

```swift
import XCTest
@testable import TaskDomain

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskDomainModule.self)
    }
}
```

```swift
// Tests/TaskPersistenceTests/ModuleSmokeTests.swift
import XCTest
@testable import TaskPersistence

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskPersistenceModule.self)
    }
}
```

```swift
// Tests/TaskAITests/ModuleSmokeTests.swift
import XCTest
@testable import TaskAI

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskAIModule.self)
    }
}
```

```swift
// Tests/TaskNotificationsTests/ModuleSmokeTests.swift
import XCTest
@testable import TaskNotifications

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskNotificationsModule.self)
    }
}
```

- [ ] **Step 3: Add the empty asset catalog metadata**

```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 4: Verify package discovery**

Run:

```bash
swift package describe
```

Expected: products list contains `TaskDomain`, `TaskPersistence`, `TaskAI`, `TaskNotifications`, and `TaskApp`. Build may still fail because app/domain sources are added in later tasks.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources
git commit -m "build: scaffold Task Swift package"
```

### Task 2: Implement the priority coordinate and quadrant rules with TDD

**Files:**

- Create: `Tests/TaskDomainTests/PriorityCoordinateTests.swift`
- Create: `Sources/TaskDomain/PriorityCoordinate.swift`
- Create: `Sources/TaskDomain/PriorityQuadrant.swift`

- [ ] **Step 1: Write failing coordinate tests**

```swift
import XCTest
@testable import TaskDomain

final class PriorityCoordinateTests: XCTestCase {
    func testAcceptsEveryValueInApprovedRange() throws {
        for urgency in -3...3 {
            for importance in -3...3 {
                XCTAssertEqual(
                    try PriorityCoordinate(urgency: urgency, importance: importance),
                    PriorityCoordinate(uncheckedUrgency: urgency, importance: importance)
                )
            }
        }
    }

    func testRejectsValuesOutsideApprovedRange() {
        XCTAssertThrowsError(try PriorityCoordinate(urgency: -4, importance: 0))
        XCTAssertThrowsError(try PriorityCoordinate(urgency: 0, importance: 4))
    }

    func testQuadrantsAndZeroAxes() throws {
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: 3).quadrant, .actNow)
        XCTAssertEqual(try PriorityCoordinate(urgency: -3, importance: 3).quadrant, .plan)
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: -3).quadrant, .delegate)
        XCTAssertEqual(try PriorityCoordinate(urgency: -3, importance: -3).quadrant, .defer)
        XCTAssertEqual(try PriorityCoordinate(urgency: 0, importance: 3).quadrant, .undecided)
        XCTAssertEqual(try PriorityCoordinate(urgency: 3, importance: 0).quadrant, .undecided)
        XCTAssertEqual(try PriorityCoordinate(urgency: 0, importance: 0).quadrant, .undecided)
    }

    func testClampingForDragInput() {
        XCTAssertEqual(PriorityCoordinate.clamped(urgency: 8, importance: -9), .init(uncheckedUrgency: 3, importance: -3))
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run:

```bash
swift test --filter PriorityCoordinateTests
```

Expected: FAIL because `PriorityCoordinate` and `PriorityQuadrant` do not exist.

- [ ] **Step 3: Implement the domain types**

```swift
// Sources/TaskDomain/PriorityQuadrant.swift
public enum PriorityQuadrant: String, Codable, CaseIterable, Sendable {
    case actNow
    case plan
    case delegate
    case `defer`
    case undecided
}
```

```swift
// Sources/TaskDomain/PriorityCoordinate.swift
import Foundation

public enum PriorityCoordinateError: Error, Equatable {
    case outOfRange(urgency: Int, importance: Int)
}

public struct PriorityCoordinate: Equatable, Codable, Hashable, Sendable {
    public static let approvedRange = -3...3

    public let urgency: Int
    public let importance: Int

    public init(urgency: Int, importance: Int) throws {
        guard Self.approvedRange.contains(urgency), Self.approvedRange.contains(importance) else {
            throw PriorityCoordinateError.outOfRange(urgency: urgency, importance: importance)
        }
        self.urgency = urgency
        self.importance = importance
    }

    public init(uncheckedUrgency urgency: Int, importance: Int) {
        precondition(Self.approvedRange.contains(urgency) && Self.approvedRange.contains(importance))
        self.urgency = urgency
        self.importance = importance
    }

    public static func clamped(urgency: Int, importance: Int) -> Self {
        .init(
            uncheckedUrgency: min(max(urgency, -3), 3),
            importance: min(max(importance, -3), 3)
        )
    }

    public var quadrant: PriorityQuadrant {
        guard urgency != 0, importance != 0 else { return .undecided }
        switch (urgency > 0, importance > 0) {
        case (true, true): return .actNow
        case (false, true): return .plan
        case (true, false): return .delegate
        case (false, false): return .defer
        }
    }
}
```

- [ ] **Step 4: Run the tests**

```bash
swift test --filter PriorityCoordinateTests
```

Expected: PASS, 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/TaskDomain Tests/TaskDomainTests/PriorityCoordinateTests.swift
git commit -m "feat: add approved priority coordinate model"
```

### Task 3: Implement the seven urgency colors

**Files:**

- Create: `Tests/TaskDomainTests/UrgencyPaletteTests.swift`
- Create: `Sources/TaskDomain/UrgencyPalette.swift`

- [ ] **Step 1: Write failing palette tests**

```swift
import XCTest
@testable import TaskDomain

final class UrgencyPaletteTests: XCTestCase {
    func testEveryApprovedUrgencyHasUniqueColor() throws {
        let colors = try (-3...3).map { try UrgencyPalette.style(for: $0).hex }
        XCTAssertEqual(Set(colors).count, 7)
    }

    func testApprovedHexValuesAndTextPolarity() throws {
        XCTAssertEqual(try UrgencyPalette.style(for: -3), .init(hex: 0x354F9E, usesDarkText: false))
        XCTAssertEqual(try UrgencyPalette.style(for: -1), .init(hex: 0x68BEB0, usesDarkText: true))
        XCTAssertEqual(try UrgencyPalette.style(for: 0), .init(hex: 0x737970, usesDarkText: false))
        XCTAssertEqual(try UrgencyPalette.style(for: 2), .init(hex: 0xE38A39, usesDarkText: true))
        XCTAssertEqual(try UrgencyPalette.style(for: 3), .init(hex: 0xD73D43, usesDarkText: false))
    }

    func testRejectsObsoleteFivePointRange() {
        XCTAssertThrowsError(try UrgencyPalette.style(for: 5))
        XCTAssertThrowsError(try UrgencyPalette.style(for: -5))
    }
}
```

- [ ] **Step 2: Verify failure**

```bash
swift test --filter UrgencyPaletteTests
```

Expected: FAIL because `UrgencyPalette` does not exist.

- [ ] **Step 3: Implement the exact approved mapping**

```swift
public struct UrgencyStyle: Equatable, Sendable {
    public let hex: UInt32
    public let usesDarkText: Bool

    public init(hex: UInt32, usesDarkText: Bool) {
        self.hex = hex
        self.usesDarkText = usesDarkText
    }
}

public enum UrgencyPalette {
    public static func style(for urgency: Int) throws -> UrgencyStyle {
        switch urgency {
        case -3: return .init(hex: 0x354F9E, usesDarkText: false)
        case -2: return .init(hex: 0x438FC1, usesDarkText: false)
        case -1: return .init(hex: 0x68BEB0, usesDarkText: true)
        case 0: return .init(hex: 0x737970, usesDarkText: false)
        case 1: return .init(hex: 0xBAA94E, usesDarkText: true)
        case 2: return .init(hex: 0xE38A39, usesDarkText: true)
        case 3: return .init(hex: 0xD73D43, usesDarkText: false)
        default: throw PriorityCoordinateError.outOfRange(urgency: urgency, importance: 0)
        }
    }
}
```

- [ ] **Step 4: Verify tests**

```bash
swift test --filter UrgencyPaletteTests
```

Expected: PASS, 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/TaskDomain/UrgencyPalette.swift Tests/TaskDomainTests/UrgencyPaletteTests.swift
git commit -m "feat: add seven-level urgency palette"
```

### Task 4: Add SwiftData models and in-memory tests

**Files:**

- Create: `Sources/TaskPersistence/Models/TaskItem.swift`
- Create: `Sources/TaskPersistence/Models/Subtask.swift`
- Create: `Sources/TaskPersistence/Models/Project.swift`
- Create: `Sources/TaskPersistence/Models/BoardColumn.swift`
- Create: `Sources/TaskPersistence/Models/Tag.swift`
- Create: `Sources/TaskPersistence/ModelContainerFactory.swift`
- Create: `Tests/TaskPersistenceTests/TaskRepositoryTests.swift`

- [ ] **Step 1: Write failing in-memory persistence tests**

```swift
import Foundation
import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class TaskRepositoryTests: XCTestCase {
    func testNewTaskUsesApprovedDefaults() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)

        let item = try repository.createTask(title: "Draft launch plan")

        XCTAssertEqual(item.urgency, 0)
        XCTAssertEqual(item.importance, 0)
        XCTAssertNil(item.project)
        XCTAssertNil(item.boardColumn)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.dueAt)
    }

    func testRejectsOutOfRangeCoordinatesBeforeSave() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskRepository(context: container.mainContext)
        let item = try repository.createTask(title: "Invalid")
        XCTAssertThrowsError(try repository.updatePriority(item, urgency: 4, importance: 0))
    }
}
```

- [ ] **Step 2: Verify failure**

```bash
swift test --filter TaskRepositoryTests
```

Expected: FAIL because SwiftData models, factory, and repository do not exist.

- [ ] **Step 3: Implement focused model files**

Use this exact public shape; keep each `@Model` in its named file:

```swift
// Sources/TaskPersistence/Models/TaskItem.swift
import Foundation
import SwiftData

@Model
public final class TaskItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var details: String
    public var urgency: Int
    public var importance: Int
    public var dueAt: Date?
    public var reminderAt: Date?
    public var estimatedMinutes: Int?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var previousBoardColumnID: UUID?
    public var manualOrder: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var project: Project?
    public var boardColumn: BoardColumn?
    @Relationship(deleteRule: .cascade, inverse: \Subtask.task) public var subtasks: [Subtask]
    @Relationship(inverse: \Tag.tasks) public var tags: [Tag]

    public init(id: UUID = UUID(), title: String, now: Date = .now) {
        self.id = id
        self.title = title
        self.details = ""
        self.urgency = 0
        self.importance = 0
        self.isCompleted = false
        self.manualOrder = now.timeIntervalSinceReferenceDate
        self.createdAt = now
        self.updatedAt = now
        self.subtasks = []
        self.tags = []
    }
}
```

```swift
// Sources/TaskPersistence/Models/Subtask.swift
import Foundation
import SwiftData

@Model
public final class Subtask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var order: Int
    public var createdAt: Date
    public var task: TaskItem?

    public init(id: UUID = UUID(), title: String, order: Int, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.isCompleted = false
        self.order = order
        self.createdAt = createdAt
    }
}
```

```swift
// Sources/TaskPersistence/Models/Project.swift
import Foundation
import SwiftData

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    public var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \BoardColumn.project) public var boardColumns: [BoardColumn]
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project) public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, colorHex: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = createdAt
        self.boardColumns = []
        self.tasks = []
    }
}
```

```swift
// Sources/TaskPersistence/Models/BoardColumn.swift
import Foundation
import SwiftData

@Model
public final class BoardColumn {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var order: Int
    public var isCompletionColumn: Bool
    public var project: Project?
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.boardColumn) public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, order: Int, isCompletionColumn: Bool = false) {
        self.id = id
        self.name = name
        self.order = order
        self.isCompletionColumn = isCompletionColumn
        self.tasks = []
    }
}
```

```swift
// Sources/TaskPersistence/Models/Tag.swift
import Foundation
import SwiftData

@Model
public final class Tag {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String?
    @Relationship(inverse: \TaskItem.tags) public var tasks: [TaskItem]

    public init(id: UUID = UUID(), name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.tasks = []
    }
}
```

- [ ] **Step 4: Add the container factory**

```swift
import SwiftData

public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskItem.self, Subtask.self, Project.self, BoardColumn.self, Tag.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] **Step 5: Add the minimal repository and pass tests**

Create `Sources/TaskPersistence/TaskRepository.swift`:

```swift
import Foundation
import SwiftData
import TaskDomain

@MainActor
public final class TaskRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createTask(title: String) throws -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskRepositoryError.emptyTitle }
        let item = TaskItem(title: trimmed)
        context.insert(item)
        try context.save()
        return item
    }

    public func updatePriority(_ item: TaskItem, urgency: Int, importance: Int) throws {
        let coordinate = try PriorityCoordinate(urgency: urgency, importance: importance)
        item.urgency = coordinate.urgency
        item.importance = coordinate.importance
        item.updatedAt = .now
        try context.save()
    }
}

public enum TaskRepositoryError: Error, Equatable {
    case emptyTitle
}
```

Run:

```bash
swift test --filter TaskRepositoryTests
```

Expected: PASS, 2 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/TaskPersistence Tests/TaskPersistenceTests
git commit -m "feat: add local SwiftData task models"
```

### Task 5: Build the native app shell

**Files:**

- Create: `Sources/TaskApp/App/AppRoute.swift`
- Create: `Sources/TaskApp/App/TaskAppShell.swift`
- Create: `Sources/TaskApp/App/TaskApplication.swift`

- [ ] **Step 1: Define stable navigation routes**

```swift
// Sources/TaskApp/App/AppRoute.swift
enum AppRoute: String, CaseIterable, Identifiable {
    case priorityMap
    case taskList
    case projectBoard
    case insights
    case settings

    var id: Self { self }
}
```

- [ ] **Step 2: Create the minimum native shell**

```swift
// Sources/TaskApp/App/TaskAppShell.swift
import SwiftUI

struct TaskAppShell: View {
    @State private var selection: AppRoute? = .priorityMap

    var body: some View {
        NavigationSplitView {
            List(AppRoute.allCases, selection: $selection) { route in
                Label(route.title, systemImage: route.symbolName).tag(route)
            }
            .navigationSplitViewColumnWidth(min: 184, ideal: 205, max: 232)
        } detail: {
            ContentUnavailableView(
                selection?.title ?? "Task",
                systemImage: selection?.symbolName ?? "checkmark.circle",
                description: Text("Feature implementation follows plans 02–04.")
            )
        }
        .frame(minWidth: 980, minHeight: 680)
    }
}

private extension AppRoute {
    var title: String {
        switch self {
        case .priorityMap: "优先级地图"
        case .taskList: "任务列表"
        case .projectBoard: "项目看板"
        case .insights: "数据洞察"
        case .settings: "设置"
        }
    }

    var symbolName: String {
        switch self {
        case .priorityMap: "square.grid.3x3"
        case .taskList: "checkmark.circle"
        case .projectBoard: "rectangle.3.group"
        case .insights: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }
}
```

- [ ] **Step 3: Add app lifecycle and model container**

```swift
// Sources/TaskApp/App/TaskApplication.swift
import SwiftUI
import TaskPersistence

@main
struct TaskApplication: App {
    private let container = try! ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup("Task") {
            TaskAppShell()
                .modelContainer(container)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建任务") {}
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(true)
            }
        }
    }
}
```

- [ ] **Step 4: Build and launch**

```bash
swift build
swift run TaskApp
```

Expected: native macOS window opens at approximately `1280 × 820`, cannot shrink below `980 × 680`, and sidebar routes are selectable. Stop the app before continuing.

- [ ] **Step 5: Commit**

```bash
git add Sources/TaskApp/App
git commit -m "feat: add native Task app shell"
```

### Task 6: Package and ad-hoc sign Task.app

**Files:**

- Create: `Packaging/Info.plist`
- Create: `scripts/package_app.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Add bundle metadata**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleExecutable</key><string>TaskApp</string>
  <key>CFBundleIdentifier</key><string>local.task.macos</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Task</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
```

- [ ] **Step 2: Add the packaging script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Task.app"
BUILD="$ROOT/.build/release"

cd "$ROOT"
swift build -c release --product TaskApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/TaskApp" "$APP/Contents/MacOS/TaskApp"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

for bundle in "$BUILD"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

codesign --force --deep --sign - "$APP"
echo "$APP"
```

- [ ] **Step 3: Make it executable and verify ignored output**

Make `scripts/package_app.sh` executable. The handoff package already includes `dist/`, `.build/`, and `.swiftpm/` in `.gitignore`; verify rather than duplicating them:

```bash
chmod +x scripts/package_app.sh
rg -n '^dist/$|^\.build/$|^\.swiftpm/$' .gitignore
```

- [ ] **Step 4: Verify the app bundle**

```bash
./scripts/package_app.sh
test -x dist/Task.app/Contents/MacOS/TaskApp
plutil -lint dist/Task.app/Contents/Info.plist
codesign --verify --deep --strict dist/Task.app
open dist/Task.app
```

Expected: all commands exit 0 and the same native shell opens from the `.app` bundle.

- [ ] **Step 5: Run all tests and scan obsolete ranges**

```bash
swift test
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources
```

Expected: tests pass; the production-source scan prints no matches. Negative tests may intentionally mention rejected obsolete values.

- [ ] **Step 6: Commit**

```bash
git add Packaging scripts/package_app.sh .gitignore
git commit -m "build: package ad-hoc signed Task app"
```

## Plan 01 completion gate

Run fresh:

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
git status --short
```

Expected: all commands exit 0; `git status --short` is empty. Continue with plan 02 only after this gate passes.
