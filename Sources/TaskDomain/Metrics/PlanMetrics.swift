public enum HealthDeductionReason: String, Equatable, Sendable {
    case overdue
    case actNowWithoutDate
    case overCapacity
    case undecided

    public var title: String {
        switch self {
        case .overdue: "逾期未完成"
        case .actNowWithoutDate: "立即处理但无日期"
        case .overCapacity: "计划负载超容量"
        case .undecided: "待判断任务"
        }
    }
}

public struct HealthDeduction: Equatable, Sendable {
    public let reason: HealthDeductionReason
    public let points: Int
    public let itemCount: Int

    public init(reason: HealthDeductionReason, points: Int, itemCount: Int) {
        self.reason = reason
        self.points = points
        self.itemCount = itemCount
    }
}

public struct PlanMetrics: Equatable, Sendable {
    public let completionRate: Double?
    public let highImportanceCount: Int
    public let plannedMinutes: Int
    public let missingEstimateCount: Int
    public let healthScore: Int
    public let deductions: [HealthDeduction]

    public init(
        completionRate: Double?,
        highImportanceCount: Int,
        plannedMinutes: Int,
        missingEstimateCount: Int,
        healthScore: Int,
        deductions: [HealthDeduction]
    ) {
        self.completionRate = completionRate
        self.highImportanceCount = highImportanceCount
        self.plannedMinutes = plannedMinutes
        self.missingEstimateCount = missingEstimateCount
        self.healthScore = healthScore
        self.deductions = deductions
    }
}
