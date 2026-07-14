import Foundation

public enum PriorityCoordinateError: Error, Equatable {
    case outOfRange(urgency: Int, importance: Int)
}

public struct PriorityCoordinate: Equatable, Codable, Hashable, Sendable {
    public static let approvedRange = -3...3

    public let urgency: Int
    public let importance: Int

    public init(urgency: Int, importance: Int) throws {
        guard Self.approvedRange.contains(urgency), Self.approvedRange.contains(importance) else {
            throw PriorityCoordinateError.outOfRange(urgency: urgency, importance: importance)
        }
        self.urgency = urgency
        self.importance = importance
    }

    public init(uncheckedUrgency urgency: Int, importance: Int) {
        precondition(Self.approvedRange.contains(urgency) && Self.approvedRange.contains(importance))
        self.urgency = urgency
        self.importance = importance
    }

    public static func clamped(urgency: Int, importance: Int) -> Self {
        .init(
            uncheckedUrgency: min(max(urgency, -3), 3),
            importance: min(max(importance, -3), 3)
        )
    }

    public var quadrant: PriorityQuadrant {
        guard urgency != 0, importance != 0 else { return .undecided }
        switch (urgency > 0, importance > 0) {
        case (true, true): return .actNow
        case (false, true): return .plan
        case (true, false): return .delegate
        case (false, false): return .defer
        }
    }
}
