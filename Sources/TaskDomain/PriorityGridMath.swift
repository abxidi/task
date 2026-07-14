public enum PriorityGridMath {
    public static func normalizedPosition(for value: Int) -> Double {
        precondition(PriorityCoordinate.approvedRange.contains(value))
        return Double(value + 3) / 6
    }

    public static func value(at normalizedPosition: Double) -> Int {
        let clamped = min(max(normalizedPosition, 0), 1)
        return Int((clamped * 6).rounded()) - 3
    }
}
