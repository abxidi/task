import Charts
import SwiftUI

struct CompletionPoint: Identifiable {
    let day: Date
    let count: Int
    var id: Date { day }
}

struct CompletionTrendChart: View {
    let points: [CompletionPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("近 7 天完成趋势")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.ink)
                Spacer()
                Text("共完成 \(total) 项")
                    .font(.system(size: 8))
                    .foregroundStyle(TaskDesignTokens.quiet)
            }

            if points.allSatisfy({ $0.count == 0 }) {
                ContentUnavailableView("暂无完成记录", systemImage: "chart.bar")
                    .frame(height: 68)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("日期", point.day, unit: .day),
                        y: .value("完成", point.count)
                    )
                    .foregroundStyle(TaskDesignTokens.acid)
                    .cornerRadius(3)
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 8))
                    }
                }
                .frame(height: 68)
                .accessibilityLabel(summary)
            }
        }
        .padding(12)
        .frame(minHeight: 102)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
    }

    private var total: Int {
        points.reduce(0) { $0 + $1.count }
    }

    private var summary: String {
        let peak = points.max(by: { $0.count < $1.count })
        if let peak, peak.count > 0 {
            return "期间完成 \(total) 项，最高一天 \(peak.count) 项"
        }
        return "期间完成 \(total) 项"
    }
}
