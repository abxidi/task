# 已完成任务移出正在进行设计

日期：2026-08-25
状态：用户已确认，进入实施

## 目标

任务被标记为完成时，立即从“正在进行”移除，避免已完成任务继续占用执行空间。

## 已确认行为

- 通过任务列表、任务编辑器或项目看板完成任务时，删除该任务关联的 `FocusEntry`。
- 任务本身仍按既有规则写入完成状态、完成时间和完成泳道。
- 重新将任务标记为未完成时，不自动重建 `FocusEntry`；用户须手动从“正在进行”菜单加入。
- 不修改任务项目、非完成泳道恢复、子任务、备注或历史完成行为。

## 实现与验证

在 `TaskPersistence` 中复用一个内部的焦点记录删除帮助方法，并在 `TaskRepository.setCompleted(_:isCompleted:)`、`TaskRepository` 的任务编辑保存路径与 `BoardWorkflowService.move(_:to:now:)` 的完成分支调用它。两个服务继续在同一个 `ModelContext.save()` 中保存任务状态和焦点记录删除，避免 UI 层散落规则或出现部分更新。XCTest 覆盖任务列表完成、任务编辑完成、看板完成列和重新打开不恢复。

参考：Apple SwiftData `ModelContext` 文档说明上下文负责删除模型并保存更改：<https://developer.apple.com/documentation/swiftdata/modelcontext>。
