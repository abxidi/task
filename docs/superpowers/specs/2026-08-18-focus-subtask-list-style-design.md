# 正在进行子任务列表样式对齐设计

日期：2026-08-18
状态：用户已确认，进入实施

## 目标

让“正在进行”视图中的子任务列表与任务编辑器（任务列表工作流使用的 `SubtaskEditor`）保持一致的基础行样式，降低同一类内容在不同入口之间的视觉跳变。

## 范围

- 统一子任务标题字体为现有任务编辑器使用的 12pt 系统字体。
- 保留“正在进行”当前的行高、内边距和控件点击区域，避免改变已确认的紧凑布局。
- 保留“正在进行”视图现有的排序手柄、行编辑、只显示未完成子任务、完成切换和拖拽行为。
- 不修改 SwiftData 模型、持久化接口或任务排序规则。

## 实现方式

在 `FocusPoolPresentation` 中增加标题字体契约，`FocusSubtaskTitleEditor` 和新增子任务输入框使用该契约渲染。行高、内边距和控件点击区域继续保留“正在进行”现有实现，不抽取跨文件共享组件。

## 验证

- 为 `FocusPoolPresentation` 增加展示契约测试，锁定标题字体大小。
- 运行聚焦测试 `swift test --filter FocusPoolPresentationTests`。
- 运行完整质量门槛：`swift test`、`swift build -c release`、`./scripts/package_app.sh`、`codesign --verify --deep --strict dist/Task.app`，并检查旧优先级范围扫描无生产源码命中。
