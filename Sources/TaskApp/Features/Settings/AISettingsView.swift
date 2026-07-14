import SwiftUI
import TaskAI

struct AISettingsView: View {
    @AppStorage("aiConfigurationJSON") private var configurationJSON = ""
    @State private var baseURLString = "https://api.openai.com/v1"
    @State private var model = "gpt-4o-mini"
    @State private var apiKey = ""
    @State private var statusMessage = ""
    @State private var hasStoredKey = false
    private let keyStore = KeychainAPIKeyStore()

    var body: some View {
        Form {
            Section("服务") {
                TextField("Base URL", text: $baseURLString)
                TextField("模型", text: $model)
                SecureField("API Key", text: $apiKey)
                if hasStoredKey {
                    Text("已保存密钥")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("保存配置") { save() }
                Button("移除配置", role: .destructive) { remove() }
            }
            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
    }

    private func load() {
        if let data = configurationJSON.data(using: .utf8),
           let configuration = try? JSONDecoder().decode(AIServiceConfiguration.self, from: data) {
            baseURLString = configuration.baseURL.absoluteString
            model = configuration.model
        }
        hasStoredKey = ((try? keyStore.read())?.isEmpty == false)
    }

    private func save() {
        do {
            guard let url = URL(string: baseURLString) else {
                statusMessage = "Base URL 无效"
                return
            }
            let configuration = try AIServiceConfiguration(baseURL: url, model: model)
            let data = try JSONEncoder().encode(configuration)
            configurationJSON = String(data: data, encoding: .utf8) ?? ""
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                try keyStore.save(trimmedKey)
                apiKey = ""
                hasStoredKey = true
            }
            statusMessage = AIAvailability.isConfigured(
                configurationData: data,
                keyStore: keyStore
            ) ? "AI 已配置" : "请填写 API Key"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func remove() {
        configurationJSON = ""
        apiKey = ""
        try? keyStore.delete()
        hasStoredKey = false
        statusMessage = "已移除 AI 配置"
    }
}
