# Task macOS 开发交接包

这份交接包面向接手实现的 Agent。当前仓库只包含已经批准的设计、UI 参考和实施计划，尚未创建应用源码。接手者应从计划 01 开始，不要先搭一个与文档无关的示例应用。

## 交付物索引

| 文件 | 用途 |
| --- | --- |
| `AGENTS.md` | 仓库级强制约束、阅读顺序和质量门槛 |
| `docs/superpowers/specs/2026-07-13-task-macos-design.md` | 产品行为、数据规则和完成标准 |
| `docs/ui/task-macos-ui-spec.md` | 原生 UI 尺寸、令牌、组件、状态和可访问性 |
| `docs/ui/task-ui-reference.html` | 可直接打开并交互的高保真视觉参考 |
| `docs/handoff/OFFICIAL_REFERENCES.md` | Apple 与 OpenAI 官方实现资料和核对状态 |
| `docs/handoff/READER_CHECKLIST.md` | 接手 Agent 开工前的理解检查 |
| `docs/handoff/START_PROMPT.md` | 可直接发给新开发 Agent 的启动提示 |
| `docs/handoff/VALIDATION.md` | 交接包已验证内容和剩余限制 |
| `docs/superpowers/plans/2026-07-13-task-macos-01-foundation.md` | 应用骨架、领域模型、本地数据和打包 |
| `docs/superpowers/plans/2026-07-13-task-macos-02-core-task-experience.md` | 任务列表、内容优先编辑器和优先级地图 |
| `docs/superpowers/plans/2026-07-13-task-macos-03-board-insights.md` | 项目看板、拖拽和可解释指标 |
| `docs/superpowers/plans/2026-07-13-task-macos-04-ai-release.md` | 可选 AI、Keychain、提醒、备份和发布验收 |

## 实施顺序

```text
01 Foundation
  -> 可启动的原生应用 + 已测试领域规则 + SwiftData + Task.app
02 Core Task Experience
  -> 可完成本地任务管理闭环 + 正方形优先级地图
03 Board & Insights
  -> 可拖拽项目工作流 + 真实指标与趋势
04 Optional AI & Release
  -> AI 渐进增强 + 提醒/备份 + 发布级验证
```

每个阶段都必须在主分支上保持可构建、可运行和可回滚。不要同时执行多个计划，因为后续计划依赖前一个计划创建的类型和路径。

## 环境前提

- macOS 14 或更高。
- 完整 Xcode 和 Command Line Tools。
- Swift 5.9 或更高。
- 不要求 Node、数据库服务或云账号。
- AI 集成测试默认使用本地 `URLProtocol` stub，不需要真实 API Key。

开始前执行：

```bash
xcode-select -p
swift --version
git status --short
```

## 目标仓库结构

```text
.
├── AGENTS.md
├── Package.swift
├── Sources
│   ├── TaskApp
│   │   ├── App
│   │   ├── Features
│   │   └── Resources
│   ├── TaskDomain
│   ├── TaskPersistence
│   ├── TaskAI
│   └── TaskNotifications
├── Tests
│   ├── TaskDomainTests
│   ├── TaskPersistenceTests
│   ├── TaskAITests
│   └── TaskNotificationsTests
├── scripts
│   └── package_app.sh
├── docs
│   ├── handoff
│   ├── ui
│   └── superpowers
└── dist
    └── Task.app
```

`dist/` 是构建产物，应加入 `.gitignore`。应用源码不依赖 UI 参考 HTML；HTML 只用于比对布局与交互。

## 核心领域接口

接手实现时保持以下命名稳定，后续计划和测试都依赖它们：

```swift
public struct PriorityCoordinate: Equatable, Codable, Sendable {
    public let urgency: Int
    public let importance: Int
}

public enum PriorityQuadrant: String, Codable, Sendable {
    case actNow
    case plan
    case delegate
    case defer
    case undecided
}

public struct PlanMetrics: Equatable, Sendable {
    public let completionRate: Double?
    public let highImportanceCount: Int
    public let plannedMinutes: Int
    public let missingEstimateCount: Int
    public let healthScore: Int
    public let deductions: [HealthDeduction]
}
```

持久化实体使用 `TaskItem`、`Subtask`、`Project`、`BoardColumn` 和 `Tag`。AI 通过协议访问领域 DTO，不直接依赖 SwiftData 模型。

## 已锁定的 UI 方向

- 安静、克制、信息密集的原生生产力工具，不采用营销页、装饰性大卡片或紫色渐变。
- 主色是石墨黑与近白灰，酸橙色只用于选中、焦点和 AI 增强状态。
- 正在做是默认首页；分布地图仍是产品最强的视觉识别点。
- 任务编辑器像轻量写作工具，管理字段不抢占内容空间。
- 看板顶部直接展示真实指标；卡片上的优先级标记与地图使用同一编码。
- AI 面板只有在配置完成后出现，未配置时主内容自然扩展，不保留空白列。

## 阶段验收

### 阶段 01

- `swift test` 通过领域和持久化测试。
- 应用可启动并显示原生三栏壳层。
- `scripts/package_app.sh` 生成可验证签名的 `dist/Task.app`。

### 阶段 02

- 不配置任何属性也能创建任务。
- 描述和子任务是编辑器主内容。
- 坐标只接受 `-3...3`，地图固定正方形，颜色和内嵌数字正确。

### 阶段 03

- 看板列可重命名、排序和拖拽任务。
- 完成列与 `isCompleted/completedAt` 保持一致。
- 所有指标来自本地真实数据，并能解释健康度扣分。

### 阶段 04

- AI 未配置时无功能缺口。
- API Key 只存在 Keychain。
- AI 建议必须经过差异审阅才可应用。
- 本地提醒、JSON 导入导出和发布验证通过。

## 需要停止并向用户确认的情况

- 想改变 `-3...3` 范围、轴含义、颜色表或零值分类。
- 想把管理属性重新放回任务编辑器主内容。
- 想引入云同步、账号、日历或后台 AI。
- Apple API 限制导致已批准交互无法原样实现。
- SwiftData 模型更改需要破坏性迁移或清空数据。
