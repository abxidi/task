import SwiftData
import SwiftUI
import TaskAI
import TaskPersistence

struct AIPlanningPanel: View {
    let tasks: [TaskItem]
    let capacityMinutes: Int
    let range: ClosedRange<Date>
    @Environment(\.modelContext) private var modelContext
    @AppStorage("aiConfigurationJSON") private var configurationJSON = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var isConfirmingScope = false
    @State private var isLoading = false
    @State private var proposal: PlanProposal?
    @State private var errorMessage: String?
    private let keyStore = KeychainAPIKeyStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("✦")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.acid)
                    .frame(width: 25, height: 25)
                    .background(TaskDesignTokens.ink, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 规划助手")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.ink)
                    Text("已配置 · 本次可选 \(tasks.count) 项")
                        .font(.system(size: 8))
                        .foregroundStyle(TaskDesignTokens.success)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(hex: 0xE1E1DB)).frame(height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("本周有一个负载风险")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(TaskDesignTokens.ink)
                        .padding(.bottom, 5)

                    Text("根据优先级、预计时长和日期生成，仅供审阅。AI 不会直接修改任务。")
                        .font(.system(size: 10))
                        .foregroundStyle(TaskDesignTokens.quiet)
                        .lineSpacing(3)
                        .padding(.bottom, 13)

                    TaskChromeButton(title: "生成周计划草案", style: .primary) {
                        selectedIDs = Set(tasks.map(\.id))
                        isConfirmingScope = true
                    }
                    .disabled(tasks.isEmpty || isLoading)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)

                    if isLoading {
                        ProgressView("生成中…")
                            .controlSize(.small)
                            .padding(.bottom, 12)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(TaskDesignTokens.danger)
                            .padding(.bottom, 12)
                    }

                    insightCard(title: "审阅后应用", body: "所有建议默认不选中，确认后才会写入任务。", risk: nil)
                    insightCard(title: "数据范围", body: "仅发送你勾选的任务标题、描述、子任务、坐标、日期与预计时长。", risk: nil)

                    Text("AI 不在后台上传数据，也不未经确认修改任务。")
                        .font(.system(size: 8))
                        .foregroundStyle(TaskDesignTokens.quiet)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color(hex: 0xE3E3DD)).frame(height: 1)
                        }
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .taskSubtleScrollIndicators()
        }
        .background(TaskDesignTokens.panel)
        .sheet(isPresented: $isConfirmingScope) {
            scopeSheet
        }
        .sheet(item: Binding(
            get: { proposal.map(IdentifiableProposal.init) },
            set: { proposal = $0?.value }
        )) { item in
            PlanReviewSheet(proposal: item.value, tasks: tasks) { reviewed in
                do {
                    let map = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                    try PlanProposalApplier(context: modelContext).apply(reviewed, tasksByID: map)
                    proposal = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func insightCard(title: String, body: String, risk: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                if let risk {
                    Text(risk)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.zoneActFG)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(TaskDesignTokens.zoneActBG, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            Text(body)
                .font(.system(size: 9))
                .foregroundStyle(TaskDesignTokens.muted)
                .lineSpacing(3)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
        .padding(.bottom, 8)
    }

    private var scopeSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("确认发送范围")
                .font(.system(size: 18, weight: .semibold, design: .serif))
            Text("将发送：标题、描述、子任务、紧急度、重要度、日期、预计时长。不会发送 API Key。")
                .font(.callout)
                .foregroundStyle(TaskDesignTokens.muted)
            List(tasks, id: \.id) { task in
                Toggle(isOn: Binding(
                    get: { selectedIDs.contains(task.id) },
                    set: { isOn in
                        if isOn { selectedIDs.insert(task.id) } else { selectedIDs.remove(task.id) }
                    }
                )) {
                    Text(task.title)
                }
            }
            .taskSubtleScrollIndicators()
            HStack {
                TaskChromeButton(title: "取消") { isConfirmingScope = false }
                Spacer()
                TaskChromeButton(title: "发送 \(selectedIDs.count) 项", style: .primary) {
                    isConfirmingScope = false
                    Task { await generate() }
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
        .background(TaskDesignTokens.panel)
    }

    private func generate() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let data = configurationJSON.data(using: .utf8),
                  let configuration = try? JSONDecoder().decode(AIServiceConfiguration.self, from: data) else {
                throw AIClientError.missingAPIKey
            }
            let client = OpenAICompatibleClient(configuration: configuration, apiKeyStore: keyStore)
            let selected = tasks.filter { selectedIDs.contains($0.id) }
            let request = PlanningRequest(
                tasks: selected.map {
                    PlanningTask(
                        id: $0.id,
                        title: $0.title,
                        details: $0.details,
                        subtasks: $0.subtasks.sorted { $0.order < $1.order }.map(\.title),
                        urgency: $0.urgency,
                        importance: $0.importance,
                        dueAt: $0.dueAt,
                        estimatedMinutes: $0.estimatedMinutes
                    )
                },
                capacityMinutes: capacityMinutes,
                rangeStart: range.lowerBound,
                rangeEnd: range.upperBound
            )
            let raw = try await client.proposePlan(request)
            proposal = try PlanProposalValidator.validate(
                raw,
                allowedTaskIDs: Set(selected.map(\.id)),
                range: range
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IdentifiableProposal: Identifiable {
    let id = UUID()
    let value: PlanProposal
}
