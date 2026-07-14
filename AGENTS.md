# Task 项目 Agent 开发说明

默认使用简体中文沟通。代码、命令、错误信息和 Apple API 名称保留英文。

## 开始前必须阅读

按以下顺序阅读，后者不得覆盖前者的产品结论：

1. `docs/superpowers/specs/2026-07-13-task-macos-design.md`：已批准的产品与技术规格。
2. `docs/ui/task-macos-ui-spec.md`：布局、视觉令牌、组件和状态规范。
3. `docs/ui/task-ui-reference.html`：可直接在浏览器打开的交互参考。
4. `docs/handoff/README.md`：交接状态、实施顺序和验收入口。
5. `docs/superpowers/plans/`：四阶段实施计划，必须按编号执行。

若文档之间存在冲突，停止实施并向用户说明冲突，不自行选择。

## 不可变产品结论

- 应用是原生 macOS 应用，最低支持 macOS 14。
- 数据只保存在本机，不增加账号、云同步或团队协作。
- 横轴是紧急度，纵轴是重要度，两个维度均为整数 `-3...3`。
- 共 `7 × 7 = 49` 个坐标；不得改回 `-5...5`。
- 四象限必须保持 `1:1` 正方形。
- 任务色块背景色表示紧急度，色块内带符号数字表示重要度。
- 任一维度为 `0` 时归为“待判断”，不计入四个象限。
- 任务编辑默认只突出标题、描述和子任务。
- 日期、提醒、预计时长、项目、完成状态、标签和坐标统一收进“任务设置”。
- “任务设置”中四象限位于其他属性上方。
- AI 是可选增强。未配置 AI 时隐藏相关入口，基础软件功能必须完整。
- AI 只生成待审阅变更，不得未经确认修改或删除任务。

## 技术与架构约束

- UI：SwiftUI；只有系统窗口、拖拽或焦点行为确实需要时才桥接 AppKit。
- 数据：SwiftData；领域规则不得写进 View。
- 网络：Foundation `URLSession`。
- 密钥：Security framework / macOS Keychain。
- 通知：UserNotifications。
- 构建：Swift Package，使用 `scripts/package_app.sh` 生成并 ad-hoc 签名 `Task.app`。
- 内部模型名使用 `TaskItem`，避免与 Swift Concurrency 的 `Task` 冲突。

目标源码结构以 `docs/handoff/README.md` 为准。保持文件职责单一，优先小型组件和纯函数。

## 开发流程

1. 按计划编号工作，不跳过阶段依赖。
2. 每项行为先写失败测试，再实现最小代码使其通过。
3. 每个计划任务完成后运行该任务列出的验证命令。
4. 每个可独立回滚的增量单独提交，不把多个阶段压成一个提交。
5. 修改公开类型或持久化模型前，先更新测试和迁移策略。
6. UI 完成后必须用真实 macOS 运行态检查窗口尺寸、键盘、VoiceOver 标签和深色模式。

## 通用质量门槛

每次准备声称完成前，至少运行：

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict dist/Task.app
```

另外检查：

- `rg -n -P -- '(?<![0-9])-5(?![0-9])|(?<![0-9])\+5(?![0-9])|11 级|11 个' Sources` 不得在生产源码中发现旧优先级范围。
- API Key 不得出现在日志、SwiftData、`UserDefaults`、测试快照或 JSON 导出中。
- AI 未配置和网络失败时，任务创建、编辑、地图、看板和指标仍可使用。
- 四象限在所有支持窗口尺寸下保持正方形，无文本或控件重叠。

## 范围控制

首版不实现 iCloud、第三方同步、账号、多人协作、日历双向同步、插件市场或后台 AI 分析。新需求只有在用户明确批准并更新设计规格后才能进入实现。
