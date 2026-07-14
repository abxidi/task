# Task macOS 04 Optional AI and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不削弱离线任务管理的前提下增加可选 AI 规划，并完成 Keychain、提醒、JSON 备份、可访问性和发布级 `.app` 验收。

**Architecture:** AI 配置、密钥、网络客户端、结构化建议和本地变更应用彼此隔离。AI 只能创建可审阅 `PlanProposal`；持久化层在用户确认后事务应用。提醒和备份通过独立协议测试，不让系统授权或网络成为基础功能依赖。

**Tech Stack:** Foundation URLSession、Security framework、UserNotifications、SwiftData、SwiftUI、XCTest、macOS 14+

---

## 前置条件

计划 01–03 全部完成。未配置 AI 的应用已能完成任务、地图、看板和指标流程。

实现任何 Apple 或 OpenAI API 前先阅读 `docs/handoff/OFFICIAL_REFERENCES.md`。OpenAI 页面在交接环境中未能远程读取，执行 Agent 必须重新核对当前官方请求字段。

## 文件结构

```text
Sources/TaskAI/AIServiceConfiguration.swift
Sources/TaskAI/APIKeyStore.swift
Sources/TaskAI/KeychainAPIKeyStore.swift
Sources/TaskAI/AIPlanningClient.swift
Sources/TaskAI/OpenAICompatibleClient.swift
Sources/TaskAI/PlanProposal.swift
Sources/TaskAI/PlanProposalValidator.swift
Sources/TaskPersistence/PlanProposalApplier.swift
Sources/TaskNotifications/ReminderScheduling.swift
Sources/TaskNotifications/UserNotificationScheduler.swift
Sources/TaskPersistence/Backup/BackupEnvelope.swift
Sources/TaskPersistence/Backup/BackupService.swift
Sources/TaskApp/Features/Settings/AISettingsView.swift
Sources/TaskApp/Features/AI/AIPlanningPanel.swift
Sources/TaskApp/Features/AI/PlanReviewSheet.swift
Sources/TaskApp/Features/Settings/BackupSettingsView.swift
Sources/TaskApp/Features/Settings/NotificationSettingsView.swift
Sources/TaskApp/Resources/Assets.xcassets/AppIcon.appiconset
Tests/TaskAITests/AIServiceConfigurationTests.swift
Tests/TaskAITests/KeychainAPIKeyStoreTests.swift
Tests/TaskAITests/OpenAICompatibleClientTests.swift
Tests/TaskAITests/PlanProposalValidatorTests.swift
Tests/TaskPersistenceTests/PlanProposalApplierTests.swift
Tests/TaskPersistenceTests/BackupServiceTests.swift
Tests/TaskNotificationsTests/UserNotificationSchedulerTests.swift
```

### Task 1: Validate AI configuration and isolate the API key

**Files:**

- Create: `Sources/TaskAI/AIServiceConfiguration.swift`
- Create: `Sources/TaskAI/APIKeyStore.swift`
- Create: `Sources/TaskAI/KeychainAPIKeyStore.swift`
- Create: `Tests/TaskAITests/AIServiceConfigurationTests.swift`
- Create: `Tests/TaskAITests/KeychainAPIKeyStoreTests.swift`

- [ ] **Step 1: Write failing configuration tests**

```swift
import XCTest
@testable import TaskAI

final class AIServiceConfigurationTests: XCTestCase {
    func testAcceptsHTTPSAndLoopbackHTTP() throws {
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: "model-a"))
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "http://127.0.0.1:11434/v1")!, model: "local"))
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "http://localhost:11434/v1")!, model: "local"))
    }

    func testRejectsRemotePlainHTTPAndEmptyModel() {
        XCTAssertThrowsError(try AIServiceConfiguration(baseURL: URL(string: "http://api.example.com/v1")!, model: "model"))
        XCTAssertThrowsError(try AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: " "))
    }
}
```

- [ ] **Step 2: Implement safe configuration**

```swift
import Foundation

public struct AIServiceConfiguration: Codable, Equatable, Sendable {
    public let baseURL: URL
    public let model: String

    public init(baseURL: URL, model: String) throws {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLoopback = baseURL.host == "localhost" || baseURL.host == "127.0.0.1" || baseURL.host == "::1"
        guard baseURL.scheme == "https" || (baseURL.scheme == "http" && isLoopback) else {
            throw AIConfigurationError.insecureURL
        }
        guard !trimmed.isEmpty else { throw AIConfigurationError.emptyModel }
        self.baseURL = baseURL
        self.model = trimmed
    }
}

public enum AIConfigurationError: Error, Equatable {
    case insecureURL
    case emptyModel
}
```

- [ ] **Step 3: Define a testable key-store protocol and fake test**

```swift
public protocol APIKeyStore: Sendable {
    func save(_ key: String) throws
    func read() throws -> String?
    func delete() throws
}
```

```swift
import XCTest
@testable import TaskAI

final class KeychainAPIKeyStoreTests: XCTestCase {
    func testRoundTripAndDelete() throws {
        let store = InMemoryAPIKeyStore()
        try store.save("secret")
        XCTAssertEqual(try store.read(), "secret")
        try store.delete()
        XCTAssertNil(try store.read())
    }
}

private final class InMemoryAPIKeyStore: APIKeyStore, @unchecked Sendable {
    private var value: String?
    func save(_ key: String) throws { value = key }
    func read() throws -> String? { value }
    func delete() throws { value = nil }
}
```

- [ ] **Step 4: Implement Security framework storage**

`KeychainAPIKeyStore` uses service `local.task.macos.ai` and account `api-key`. Save first deletes any existing item, then calls `SecItemAdd`; read uses `SecItemCopyMatching`; delete treats `errSecItemNotFound` as success. Never convert the key to log output.

```swift
import Foundation
import Security

public struct KeychainAPIKeyStore: APIKeyStore {
    private let service = "local.task.macos.ai"
    private let account = "api-key"
    public init() {}

    public func save(_ key: String) throws {
        try delete()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: Data(key.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func read() throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.status(status) }
        return String(decoding: data, as: UTF8.self)
    }

    public func delete() throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}

public enum KeychainError: Error { case status(OSStatus) }
```

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter AIServiceConfigurationTests
swift test --filter KeychainAPIKeyStoreTests
git add Sources/TaskAI Tests/TaskAITests
git commit -m "feat: add secure optional AI configuration"
```

### Task 2: Implement and stub-test the OpenAI-compatible client

**Files:**

- Create: `Sources/TaskAI/AIPlanningClient.swift`
- Create: `Sources/TaskAI/OpenAICompatibleClient.swift`
- Create: `Sources/TaskAI/PlanProposal.swift`
- Create: `Tests/TaskAITests/OpenAICompatibleClientTests.swift`
- Create: `Tests/TaskAITests/URLProtocolStub.swift`

- [ ] **Step 1: Define request and client contracts**

```swift
import Foundation

public struct PlanningTask: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let details: String
    public let subtasks: [String]
    public let urgency: Int
    public let importance: Int
    public let dueAt: Date?
    public let estimatedMinutes: Int?
}

public struct PlanningRequest: Codable, Equatable, Sendable {
    public let tasks: [PlanningTask]
    public let capacityMinutes: Int
    public let rangeStart: Date
    public let rangeEnd: Date
}

public protocol AIPlanningClient: Sendable {
    func proposePlan(_ request: PlanningRequest) async throws -> PlanProposal
}
```

Add the allow-listed response model now so the client target compiles before Task 3:

```swift
import Foundation

public struct PlanProposal: Codable, Equatable, Sendable {
    public let summary: String
    public let changes: [ProposedTaskChange]
}

public struct ProposedTaskChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let dueAt: Date?
    public let estimatedMinutes: Int?
    public let addedSubtasks: [String]
    public let reason: String
}

public struct ReviewedTaskChange: Equatable, Sendable {
    public let proposal: ProposedTaskChange
    public let isAccepted: Bool
}
```

The model intentionally has no delete/archive field.

- [ ] **Step 2: Write URLProtocol stub tests**

The test must assert:

- Request URL appends `chat/completions` to the configured base URL.
- Authorization header is `Bearer <key>`.
- Body contains configured model and selected task fields only.
- `401`, `429`, `500`, malformed JSON, and timeout map to distinct `AIClientError` values.
- No test prints request headers.

Use an ephemeral `URLSessionConfiguration` whose `protocolClasses` is `[URLProtocolStub.self]`; never call a real service.

```swift
import Foundation
@testable import TaskAI

final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: AIClientError.invalidResponse)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

Reset `URLProtocolStub.handler = nil` in `tearDown` so tests cannot leak request state.

- [ ] **Step 3: Implement response DTOs and the actor client**

```swift
import Foundation

public actor OpenAICompatibleClient: AIPlanningClient {
    private let configuration: AIServiceConfiguration
    private let apiKeyStore: APIKeyStore
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(configuration: AIServiceConfiguration, apiKeyStore: APIKeyStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.apiKeyStore = apiKeyStore
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    public func proposePlan(_ planningRequest: PlanningRequest) async throws -> PlanProposal {
        guard let key = try apiKeyStore.read(), !key.isEmpty else { throw AIClientError.missingAPIKey }
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(try ChatRequest.make(model: configuration.model, planningRequest: planningRequest))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw AIClientError.authentication
        case 429: throw AIClientError.rateLimited
        default: throw AIClientError.server(status: http.statusCode)
        }
        let chat = try decoder.decode(ChatResponse.self, from: data)
        guard let json = chat.choices.first?.message.content.data(using: .utf8) else { throw AIClientError.invalidResponse }
        return try decoder.decode(PlanProposal.self, from: json)
    }
}
```

`ChatRequest.make` uses a fixed system message that asks for the exact `PlanProposal` JSON shape and states that deletion is forbidden. The user message is the JSON-encoded `PlanningRequest`; never interpolate task text into the system instruction.

Create the private wire DTOs in `OpenAICompatibleClient.swift`:

```swift
private struct ChatRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let model: String
    let messages: [Message]

    static func make(model: String, planningRequest: PlanningRequest) throws -> Self {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(planningRequest)
        guard let payload = String(data: data, encoding: .utf8) else { throw AIClientError.encoding }
        let system = """
        Return only JSON matching PlanProposal. Allowed changes: dueAt, estimatedMinutes, addedSubtasks. Deletion and archival are forbidden.
        """
        return .init(model: model, messages: [
            .init(role: "system", content: system),
            .init(role: "user", content: payload),
        ])
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

public enum AIClientError: Error, Equatable {
    case missingAPIKey
    case encoding
    case invalidResponse
    case authentication
    case rateLimited
    case server(status: Int)
}
```

- [ ] **Step 4: Verify tests and commit**

```bash
swift test --filter OpenAICompatibleClientTests
git add Sources/TaskAI Tests/TaskAITests/OpenAICompatibleClientTests.swift
git commit -m "feat: add stub-tested AI planning client"
```

### Task 3: Validate proposals and apply only reviewed changes

**Files:**

- Create: `Sources/TaskAI/PlanProposalValidator.swift`
- Create: `Tests/TaskAITests/PlanProposalValidatorTests.swift`
- Create: `Sources/TaskPersistence/PlanProposalApplier.swift`
- Create: `Tests/TaskPersistenceTests/PlanProposalApplierTests.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Assert the response model remains allow-listed**

Add a compile-time construction test for `PlanProposal` and encode it to JSON. Assert the JSON contains `dueAt`, `estimatedMinutes`, and `addedSubtasks`, and contains neither `delete` nor `archive` keys.

- [ ] **Step 2: Write validator tests**

Reject proposals when:

- A task ID is not in the user-approved task set.
- Estimated minutes are non-positive or exceed 24 hours.
- A date is outside the requested planning range.
- Added subtask title is blank or longer than 300 characters.
- More than 100 changes or more than 20 subtasks per task are returned.

- [ ] **Step 3: Implement validator returning field errors**

`PlanProposalValidator.validate(_:allowedTaskIDs:range:)` returns a validated proposal or throws `PlanProposalValidationError` with an array of exact failures. Do not silently drop invalid changes.

```swift
import Foundation

public enum PlanProposalIssue: Equatable, Sendable {
    case tooManyChanges(Int)
    case unknownTask(UUID)
    case invalidEstimate(taskID: UUID, minutes: Int)
    case dateOutsideRange(taskID: UUID)
    case tooManySubtasks(taskID: UUID, count: Int)
    case invalidSubtaskTitle(taskID: UUID, index: Int)
}

public struct PlanProposalValidationError: Error, Equatable, Sendable {
    public let issues: [PlanProposalIssue]
}

public enum PlanProposalValidator {
    public static func validate(
        _ proposal: PlanProposal,
        allowedTaskIDs: Set<UUID>,
        range: ClosedRange<Date>
    ) throws -> PlanProposal {
        var issues: [PlanProposalIssue] = []
        if proposal.changes.count > 100 { issues.append(.tooManyChanges(proposal.changes.count)) }

        for change in proposal.changes {
            if !allowedTaskIDs.contains(change.taskID) { issues.append(.unknownTask(change.taskID)) }
            if let minutes = change.estimatedMinutes, !(1...1_440).contains(minutes) {
                issues.append(.invalidEstimate(taskID: change.taskID, minutes: minutes))
            }
            if let date = change.dueAt, !range.contains(date) {
                issues.append(.dateOutsideRange(taskID: change.taskID))
            }
            if change.addedSubtasks.count > 20 {
                issues.append(.tooManySubtasks(taskID: change.taskID, count: change.addedSubtasks.count))
            }
            for (index, title) in change.addedSubtasks.enumerated() {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.count > 300 {
                    issues.append(.invalidSubtaskTitle(taskID: change.taskID, index: index))
                }
            }
        }

        guard issues.isEmpty else { throw PlanProposalValidationError(issues: issues) }
        return proposal
    }
}
```

- [ ] **Step 4: Write proposal-applier transaction tests**

Tests must prove:

- Unaccepted changes do nothing.
- Accepted changes update only due date, estimate, and appended subtasks.
- Missing task aborts the whole operation.
- A forced context save error leaves all tasks unchanged.

- [ ] **Step 5: Implement one-save application**

Before adding the applier, update `Package.swift` so `TaskPersistence` depends on `TaskAI` and `TaskPersistenceTests` directly depends on `TaskAI`. This is a one-way dependency: `TaskAI -> TaskDomain`; `TaskPersistence -> TaskAI + TaskDomain`; there is no cycle. Add `import TaskAI` to the applier and its tests.

```swift
import Foundation
import SwiftData
import TaskAI

@MainActor
public final class PlanProposalApplier {
    private let context: ModelContext
    private let save: () throws -> Void

    public init(context: ModelContext, save: (() throws -> Void)? = nil) {
        self.context = context
        self.save = save ?? { try context.save() }
    }

    public func apply(_ reviewed: [ReviewedTaskChange], tasksByID: [UUID: TaskItem]) throws {
        let accepted = reviewed.filter(\.isAccepted).map(\.proposal)
        do {
            for change in accepted {
                guard let task = tasksByID[change.taskID] else { throw PlanApplyError.missingTask(change.taskID) }
                task.dueAt = change.dueAt
                task.estimatedMinutes = change.estimatedMinutes
                let start = task.subtasks.count
                task.subtasks.append(contentsOf: change.addedSubtasks.enumerated().map { offset, title in
                    Subtask(title: title, order: start + offset)
                })
                task.updatedAt = .now
            }
            try save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

public enum PlanApplyError: Error, Equatable {
    case missingTask(UUID)
}
```

The forced-save-error test passes a throwing `save` closure and asserts `context.rollback()` restores every touched task and relationship.

- [ ] **Step 6: Verify and commit**

```bash
swift test --filter PlanProposalValidatorTests
swift test --filter PlanProposalApplierTests
git add Sources/TaskAI Sources/TaskPersistence Tests
git commit -m "feat: validate and review AI plan changes"
```

### Task 4: Add progressive AI UI

**Files:**

- Create: `Sources/TaskApp/Features/Settings/AISettingsView.swift`
- Create: `Sources/TaskApp/Features/AI/AIPlanningPanel.swift`
- Create: `Sources/TaskApp/Features/AI/PlanReviewSheet.swift`
- Modify: `Sources/TaskApp/Features/Board/ProjectBoardScreen.swift`
- Modify: `Sources/TaskApp/Features/PriorityMap/PriorityMapScreen.swift`

- [ ] **Step 1: Implement AI settings without exposing the key**

Fields: Base URL, model, SecureField API Key, “测试连接”, and “移除配置”. Persist Base URL/model to app preferences only after validation. Persist key through `APIKeyStore`. Never populate `SecureField` with the stored key; show only “已保存密钥”.

- [ ] **Step 2: Derive one configured state**

`AIAvailability.isConfigured` is true only when configuration decodes and `APIKeyStore.read()` returns a non-empty key. Views observe this state. Do not duplicate checks in each screen.

- [ ] **Step 3: Hide AI surfaces when unconfigured**

When false: no AI toolbar buttons, panel, promotional empty state, or reserved inspector width. Compare with the AI toggle in `docs/ui/task-ui-reference.html`.

- [ ] **Step 4: Add the data-scope confirmation sheet**

Before request, show all selected tasks with checkboxes and exactly which fields will be sent. Default selected tasks match the current project/range; user can remove any item. The send button states the item count.

- [ ] **Step 5: Add review with default-unchecked changes**

`PlanReviewSheet` shows before/after values and an unchecked checkbox per change. “应用所选变更” is disabled until at least one item is accepted.

- [ ] **Step 6: Verify both states and commit**

Run app twice: with an empty Keychain and with a local stub configuration. Confirm unconfigured layout has no empty AI column; configured layout can reach scope confirmation and review without real network.

```bash
git add Sources/TaskApp/Features/AI Sources/TaskApp/Features/Settings/AISettingsView.swift Sources/TaskApp/Features/Board Sources/TaskApp/Features/PriorityMap
git commit -m "feat: add optional reviewed AI planning UI"
```

### Task 5: Add local reminder scheduling

**Files:**

- Create: `Sources/TaskNotifications/ReminderScheduling.swift`
- Create: `Sources/TaskNotifications/UserNotificationScheduler.swift`
- Create: `Tests/TaskNotificationsTests/UserNotificationSchedulerTests.swift`
- Create: `Sources/TaskApp/Features/Settings/NotificationSettingsView.swift`

- [ ] **Step 1: Define a mockable scheduler**

```swift
import Foundation

public struct TaskReminder: Equatable, Sendable {
    public let taskID: UUID
    public let title: String
    public let fireAt: Date
}

public protocol ReminderScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(_ reminder: TaskReminder) async throws
    func cancel(taskID: UUID) async
}
```

- [ ] **Step 2: Write tests against a notification-center wrapper**

Inject a protocol wrapping `UNUserNotificationCenter`. Test identifier `task.<UUID>`, title, calendar trigger, update replacing the same identifier, and cancel removing pending requests.

- [ ] **Step 3: Implement UserNotifications adapter**

Request authorization only when the user first sets a reminder, not at app launch. When denied, keep `reminderAt` in the task and show a non-blocking setting status.

- [ ] **Step 4: Wire task saves**

After a successful task save: schedule/update if `reminderAt` exists; cancel if removed or task completed. Notification failure must not roll back the task save; show a recoverable warning.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter UserNotificationSchedulerTests
git add Sources/TaskNotifications Tests/TaskNotificationsTests Sources/TaskApp/Features/Settings/NotificationSettingsView.swift
git commit -m "feat: add local task reminders"
```

### Task 6: Add versioned JSON backup and atomic import

**Files:**

- Create: `Sources/TaskPersistence/Backup/BackupEnvelope.swift`
- Create: `Sources/TaskPersistence/Backup/BackupService.swift`
- Create: `Tests/TaskPersistenceTests/BackupServiceTests.swift`
- Create: `Sources/TaskApp/Features/Settings/BackupSettingsView.swift`

- [ ] **Step 1: Define versioned Codable snapshots**

`BackupEnvelope` contains `schemaVersion = 1`, `exportedAt`, projects, columns, tasks, subtasks, and tags. Use DTOs, not direct SwiftData model encoding. Exclude AI configuration, API Key, notification authorization state, and local file paths.

- [ ] **Step 2: Write round-trip and rejection tests**

Tests cover full round-trip, unknown version, duplicate IDs, missing relationship targets, more than one completion column, and urgency/importance outside `-3...3`. Assert failed import writes zero models.

- [ ] **Step 3: Implement export and validate-before-write import**

```swift
public protocol BackupServicing {
    func exportSnapshot(now: Date) throws -> Data
    func validateImport(_ data: Data) throws -> BackupEnvelope
    func applyImport(_ envelope: BackupEnvelope) throws
}
```

`validateImport` decodes and validates the entire graph. `applyImport` inserts only a previously validated envelope and performs one save.

- [ ] **Step 4: Add native file importer/exporter UI**

Use `.fileExporter` with UTType JSON and `.fileImporter`. Show validation summary before destructive replace. Require explicit confirmation; preserve current data on any error.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter BackupServiceTests
git add Sources/TaskPersistence/Backup Tests/TaskPersistenceTests/BackupServiceTests.swift Sources/TaskApp/Features/Settings/BackupSettingsView.swift
git commit -m "feat: add local JSON backup and restore"
```

### Task 7: Finish icon, accessibility, dark mode, and release verification

**Files:**

- Create: `Sources/TaskApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: app icon PNG variants under the same directory
- Modify: `Packaging/Info.plist`
- Modify: views failing the checks below
- Modify: `scripts/package_app.sh`

- [ ] **Step 1: Create the approved app icon**

Use a flat graphite rounded square, acid-lime `T`/checklist mark, and no gradient. Generate a 1024 px master, then `16, 32, 64, 128, 256, 512, 1024` px PNG variants with `sips`. Add valid macOS app-icon `Contents.json` and set `CFBundleIconName` to `AppIcon`.

- [ ] **Step 2: Run accessibility audit**

Using Accessibility Inspector:

- Every task marker reads title, urgency, importance, and quadrant.
- Icon-only buttons have labels and help text.
- Map is reachable by keyboard and supports arrow movement.
- Charts provide summaries.
- Increase Contrast leaves markers distinguishable.

- [ ] **Step 3: Verify visual modes**

Run light, dark, Increase Contrast, and Reduce Motion. Confirm map remains square at `980 × 680`, `1280 × 820`, and `1600 × 1000`. No text or controls overlap.

- [ ] **Step 4: Scan secrets and obsolete rules**

```bash
rg -n 'Bearer |api[_-]?key|secret' Sources Tests --glob '!**/*Tests.swift'
rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources docs/ui
```

Expected: first scan finds only intentional header construction with no literal key; second scan finds no obsolete product values in production source or UI references.

- [ ] **Step 5: Run full release build**

```bash
swift test
swift build -c release
./scripts/package_app.sh
plutil -lint dist/Task.app/Contents/Info.plist
codesign --verify --deep --strict dist/Task.app
open dist/Task.app
```

Expected: commands exit 0; packaged app launches; title-only task creation works with Wi-Fi disabled and no AI config.

- [ ] **Step 6: Commit**

```bash
git add Sources/TaskApp/Resources Packaging Sources Tests scripts
git commit -m "release: complete Task macOS first version"
```

## Plan 04 completion gate

The application is complete only when all of the following are evidenced in a fresh run:

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
```

Manual acceptance:

- With AI unconfigured and network disabled, all base workflows work.
- API Key is absent from preferences, database, backup, logs, and source.
- AI changes are default-unchecked and require explicit review.
- Reminder denial does not block task saving.
- Invalid backup import writes nothing.
- Priority map remains square and strictly `-3...3`.
