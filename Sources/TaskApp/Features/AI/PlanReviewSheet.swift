import SwiftUI
import TaskAI
import TaskPersistence

struct PlanReviewSheet: View {
    let proposal: PlanProposal
    let tasks: [TaskItem]
    let onApply: ([ReviewedTaskChange]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accepted: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("审阅 AI 建议")
                .font(.title2.weight(.semibold))
            Text(proposal.summary)
                .foregroundStyle(.secondary)
            List(proposal.changes) { change in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { accepted.contains(change.id) },
                        set: { isOn in
                            if isOn { accepted.insert(change.id) } else { accepted.remove(change.id) }
                        }
                    )) {
                        Text(taskTitle(for: change.taskID))
                            .font(.headline)
                    }
                    Text(change.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let dueAt = change.dueAt {
                        Text("截止日期 → \(dueAt.formatted())")
                    }
                    if let minutes = change.estimatedMinutes {
                        Text("预计时长 → \(minutes) 分钟")
                    }
                    if !change.addedSubtasks.isEmpty {
                        Text("新增子任务：\(change.addedSubtasks.joined(separator: "、"))")
                    }
                }
                .padding(.vertical, 4)
            }
            .taskSubtleScrollIndicators()
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("应用所选变更") {
                    let reviewed = proposal.changes.map {
                        ReviewedTaskChange(proposal: $0, isAccepted: accepted.contains($0.id))
                    }
                    onApply(reviewed)
                    dismiss()
                }
                .disabled(accepted.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }

    private func taskTitle(for id: UUID) -> String {
        tasks.first(where: { $0.id == id })?.title ?? id.uuidString
    }
}
