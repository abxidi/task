import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

struct InsightsScreen: View {
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name)
    private var projects: [Project]
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @AppStorage("dailyCapacityMinutes") private var capacityMinutes = 480

    @State private var rangeDays = 7
    @State private var selectedProjectID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    eyebrow: "数据洞察 · 近 \(rangeDays) 天",
                    title: "回顾执行节奏"
                )

                HStack(spacing: 12) {
                    Picker("范围", selection: $rangeDays) {
                        Text("本周").tag(7)
                        Text("本月").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    Picker("项目", selection: $selectedProjectID) {
                        Text("全部项目").tag(Optional<UUID>.none)
                        ForEach(projects, id: \.id) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .frame(width: 200)
                    Spacer()
                }

                MetricsStrip(metrics: metrics)

                HStack(alignment: .top, spacing: 10) {
                    CompletionTrendChart(points: trendPoints)
                        .frame(maxWidth: .infinity)
                    QuadrantDistributionChart(distribution: distribution)
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("健康度扣分明细")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.ink)
                    VStack(spacing: 0) {
                        ForEach(sortedDeductions) { deduction in
                            HStack {
                                Text(deduction.reason.title)
                                    .font(.system(size: 11))
                                Spacer()
                                Text("\(deduction.itemCount) 项")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TaskDesignTokens.quiet)
                                    .frame(width: 48, alignment: .trailing)
                                Text("-\(deduction.points)")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(deduction.points > 0 ? TaskDesignTokens.danger : TaskDesignTokens.quiet)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(TaskDesignTokens.line).frame(height: 1)
                            }
                        }
                    }
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(TaskDesignTokens.line, lineWidth: 1))
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 25)
        }
        .background(TaskDesignTokens.canvas)
    }

    private var scopedTasks: [TaskItem] {
        guard let selectedProjectID else { return allTasks }
        return allTasks.filter { $0.project?.id == selectedProjectID }
    }

    private var metricsTasks: [MetricsTask<UUID>] {
        scopedTasks.map {
            MetricsTask(
                id: $0.id,
                coordinate: .init(uncheckedUrgency: $0.urgency, importance: $0.importance),
                dueAt: $0.dueAt,
                estimatedMinutes: $0.estimatedMinutes,
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt
            )
        }
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: rangeDays, to: start) ?? start
        return start...end
    }

    private var metrics: PlanMetrics {
        PlanMetricsCalculator.calculate(
            tasks: metricsTasks,
            range: dateRange,
            capacityMinutes: capacityMinutes,
            now: .now
        )
    }

    private var trendPoints: [CompletionPoint] {
        PlanMetricsCalculator.completionTrend(tasks: metricsTasks, range: dateRange)
            .map { CompletionPoint(day: $0.day, count: $0.count) }
    }

    private var distribution: [PriorityQuadrant: Int] {
        PlanMetricsCalculator.quadrantDistribution(tasks: metricsTasks)
    }

    private var sortedDeductions: [HealthDeduction] {
        metrics.deductions.sorted { $0.points > $1.points }
    }
}

extension HealthDeduction: Identifiable {
    public var id: String { reason.rawValue }
}
