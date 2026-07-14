import Charts
import SwiftUI
import TaskDomain

struct QuadrantDistributionChart: View {
    let distribution: [PriorityQuadrant: Int]

    private var slices: [(quadrant: PriorityQuadrant, count: Int)] {
        PriorityQuadrant.allCases.map { ($0, distribution[$0] ?? 0) }
    }

    private var total: Int {
        slices.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if total == 0 {
                ContentUnavailableView("暂无未完成任务", systemImage: "chart.pie")
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                Chart(slices, id: \.quadrant) { slice in
                    SectorMark(
                        angle: .value("数量", slice.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 1
                    )
                    .foregroundStyle(color(for: slice.quadrant))
                }
                .chartLegend(.hidden)
                .frame(width: 72, height: 72)
                .overlay {
                    Text("\(total)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(TaskDesignTokens.ink)
                }
                .accessibilityLabel(summary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(slices, id: \.quadrant) { slice in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: slice.quadrant))
                                .frame(width: 7, height: 7)
                            Text("\(slice.quadrant.displayName) \(percent(slice.count))")
                                .font(.system(size: 8))
                                .foregroundStyle(TaskDesignTokens.muted)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(minHeight: 102)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
    }

    private func percent(_ count: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(count) / Double(total) * 100).rounded()))%"
    }

    private var summary: String {
        slices.map { "\($0.quadrant.displayName) \($0.count)" }.joined(separator: "，")
    }

    private func color(for quadrant: PriorityQuadrant) -> Color {
        switch quadrant {
        case .actNow: Color(hex: 0xD73D43)
        case .plan: Color(hex: 0x67934E)
        case .delegate: Color(hex: 0x269276)
        case .defer: Color(hex: 0xB9BCB4)
        case .undecided: Color(hex: 0xBAA94E)
        }
    }
}
