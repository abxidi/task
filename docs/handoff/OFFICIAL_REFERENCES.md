# 官方实现资料索引

核对日期：2026-07-13

这些链接用于执行计划时核对 API 签名和平台行为。产品规则仍以设计规格为准；官方 API 变化不得被用来静默修改产品范围。

## Apple

| 主题 | 官方资料 | 对应计划 |
| --- | --- | --- |
| 三栏原生导航 | [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) | 01、02 |
| SwiftData 容器 | [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer) | 01 |
| SwiftData 模型宏 | [Model](<https://developer.apple.com/documentation/swiftdata/model()>) | 01 |
| Swift Charts | [Charts](https://developer.apple.com/documentation/charts) | 03 |
| 拖放目标 | [dropDestination](<https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:)>) | 03 |
| Keychain | [Keychain Services](https://developer.apple.com/documentation/security/keychain-services) | 04 |
| 本地通知 | [UserNotifications](https://developer.apple.com/documentation/usernotifications) | 04 |
| URLSession async 请求 | [URLSession data(for:delegate:)](<https://developer.apple.com/documentation/foundation/urlsession/data(for:delegate:)>) | 04 |
| 文件导出 | [fileExporter](<https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)>) | 04 |
| 可访问性标签 | [accessibilityLabel](<https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv>) | 02–04 |

以上核心 Apple 页面在核对日期通过只读 HTTP 状态检查，返回 200。执行 Agent 仍应在写入框架相关代码前打开对应具体章节，核对当前 Xcode SDK 的签名和可用性。

## OpenAI-compatible 接口

首版 AI 适配器采用用户可配置的 OpenAI-compatible Chat Completions 形状，不绑定固定模型名称。

- 官方 API reference 候选入口：[Create chat completion](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- 官方文本生成指南：[Text generation](https://developers.openai.com/api/docs/guides/text)

当前环境访问 `developers.openai.com` 返回 403，因此本次交接无法把远程内容标记为已读取。执行计划 04 的 Agent 必须在实现 `ChatRequest`、`ChatResponse` 和错误映射前重新访问官方文档或 OpenAI Developer Docs MCP，核对以下内容：

- `POST /chat/completions` 的当前请求和响应字段。
- Authorization header 格式。
- 结构化 JSON 输出能力及兼容性限制。
- 当前错误状态码和响应体。

若目标 OpenAI-compatible 服务不支持官方 OpenAI 的结构化输出字段，保持本计划的协议边界，通过适配器解析严格 JSON 文本，不要把服务差异泄漏到领域模型。

## 实施时的核对规则

1. 先从 `Package.swift` 确认 macOS 和 Swift 版本。
2. 打开本任务涉及的最小官方页面，不从博客复制 API。
3. 发现签名变化时先更新计划和测试，再改代码。
4. Apple API 限制若影响已批准交互，停止并向用户确认。
5. 无法验证的 API 必须在提交说明中标记为未验证，不能以记忆代替证据。
