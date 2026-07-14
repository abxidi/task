import SwiftUI
import TaskDomain

struct MetricsStrip: View {
    let metrics: PlanMetrics
    @State private var showHealth = false

    var body: some View {
        HStack(spacing: 1) {
            metric(title: "完成率", value: completionText, note: nil, label: "完成率 \(completionText)")
            metric(title: "高重要任务", value: "\(metrics.highImportanceCount)", note: nil, label: "高重要任务 \(metrics.highImportanceCount)")
            metric(title: "计划负载", value: loadText, note: overloadNote, label: "计划负载 \(loadText)", warning: overloadNote != nil)
            Button {
                showHealth.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("健康度")
                        .font(.system(size: 9))
                        .foregroundStyle(TaskDesignTokens.quiet)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(metrics.healthScore)")
                            .font(.system(size: 19, weight: .semibold).monospacedDigit())
                            .foregroundStyle(TaskDesignTokens.ink)
                        Text("/ 100")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(TaskDesignTokens.success)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: TaskDesignTokens.metricHeight, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(TaskDesignTokens.raised)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHealth) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("健康度扣分")
                        .font(.headline)
                    ForEach(metrics.deductions.filter { $0.points > 0 }, id: \.reason) { deduction in
                        HStack {
                            Text(deduction.reason.title)
                            Spacer()
                            Text("\(deduction.itemCount) 项 · -\(deduction.points)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    Divider()
                    Text("合计扣 \(metrics.deductions.reduce(0) { $0 + $1.points }) 分，得分 \(metrics.healthScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(width: 280)
            }
            .accessibilityLabel("计划健康度 \(metrics.healthScore)")
        }
        .background(TaskDesignTokens.line, in: RoundedRectangle(cornerRadius: 7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(TaskDesignTokens.line, lineWidth: 1))
    }

    private var completionText: String {
        guard let rate = metrics.completionRate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }

    private var loadText: String {
        let hours = Double(metrics.plannedMinutes) / 60
        if metrics.missingEstimateCount > 0 {
            return String(format: "%.1fh", hours)
        }
        return String(format: "%.1fh", hours)
    }

    private var overloadNote: String? {
        metrics.missingEstimateCount > 0 ? "缺估 \(metrics.missingEstimateCount)" : nil
    }

    private func metric(title: String, value: String, note: String?, label: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(TaskDesignTokens.quiet)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 19, weight: .semibold).monospacedDigit())
                    .foregroundStyle(TaskDesignTokens.ink)
                if let note {
                    Text(note)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(warning ? TaskDesignTokens.danger : TaskDesignTokens.success)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: TaskDesignTokens.metricHeight, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(TaskDesignTokens.raised)
        .accessibilityLabel(label)
    }
}
