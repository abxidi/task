import Foundation

struct DoubleControlDetector: Sendable {
    enum Event: Sendable {
        case controlDown
        case controlUp
        case otherKey
    }

    private enum State: Sendable {
        case idle
        case firstControlDown
        case firstControlReleased(at: TimeInterval)
        case secondControlDown(firstReleasedAt: TimeInterval)
    }

    private static let maximumInterval: TimeInterval = 0.4
    private var state: State = .idle

    mutating func handle(_ event: Event, at timestamp: TimeInterval) -> Bool {
        switch (state, event) {
        case (_, .otherKey):
            state = .idle
            return false

        case (.idle, .controlDown):
            state = .firstControlDown
            return false

        case (.firstControlDown, .controlUp):
            state = .firstControlReleased(at: timestamp)
            return false

        case (.firstControlReleased(let firstReleasedAt), .controlDown):
            if timestamp - firstReleasedAt <= Self.maximumInterval {
                state = .secondControlDown(firstReleasedAt: firstReleasedAt)
            } else {
                state = .firstControlDown
            }
            return false

        case (.secondControlDown(let firstReleasedAt), .controlUp):
            let triggered = timestamp - firstReleasedAt <= Self.maximumInterval
            state = .idle
            return triggered

        case (_, .controlDown), (_, .controlUp):
            state = .idle
            return false
        }
    }
}
