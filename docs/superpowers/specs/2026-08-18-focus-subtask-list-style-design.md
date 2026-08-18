# 正在进行子任务列表样式对齐设计

日期：2026-08-18
状态：用户已确认，进入实施

## 目标

让“正在进行”视图中的子任务列表与任务编辑器（任务列表工作流使用的 `SubtaskEditor`）保持一致的基础行样式，降低同一类内容在不同入口之间的视觉跳变。

## 范围

- 统一子任务标题字体为现有任务编辑器使用的 12pt 系统字体。
- 统一子任务行的复选框图标框尺寸为 18pt。
- 统一子任务行最小高度为 40pt，水平内边距 10pt、垂直内边距 8pt。
- 保留“正在进行”视图现有的排序手柄、行编辑、只显示未完成子任务、完成切换和拖拽行为。
- 不修改 SwiftData 模型、持久化接口或任务排序规则。

## 实现方式

在 `FocusPoolPresentation` 中增加只表达视觉契约的常量，`FocusEntryRow.subtaskRow` 和 `FocusSubtaskTitleEditor` 使用这些常量渲染。样式常量与 `TaskEditorSubtaskEntryStyle` 的数值保持一致，但不抽取跨文件共享组件，避免把“正在进行”专属交互与编辑器图片附件/删除操作耦合。

## 验证

- 为 `FocusPoolPresentation` 增加展示契约测试，锁定字体大小、图标框、行高和内边距。
- 运行聚焦测试 `swift test --filter FocusPoolPresentationTests`。
- 运行完整质量门槛：`swift test`、`swift build -c release`、`./scripts/package_app.sh`、`codesign --verify --deep --strict dist/Task.app`，并检查旧优先级范围扫描无生产源码命中。
