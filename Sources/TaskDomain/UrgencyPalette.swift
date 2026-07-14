public struct UrgencyStyle: Equatable, Sendable {
    public let hex: UInt32
    public let usesDarkText: Bool

    public init(hex: UInt32, usesDarkText: Bool) {
        self.hex = hex
        self.usesDarkText = usesDarkText
    }
}

public enum UrgencyPalette {
    public static func style(for urgency: Int) throws -> UrgencyStyle {
        switch urgency {
        case -3: return .init(hex: 0x354F9E, usesDarkText: false)
        case -2: return .init(hex: 0x438FC1, usesDarkText: false)
        case -1: return .init(hex: 0x68BEB0, usesDarkText: true)
        case 0: return .init(hex: 0x737970, usesDarkText: false)
        case 1: return .init(hex: 0xBAA94E, usesDarkText: true)
        case 2: return .init(hex: 0xE38A39, usesDarkText: true)
        case 3: return .init(hex: 0xD73D43, usesDarkText: false)
        default: throw PriorityCoordinateError.outOfRange(urgency: urgency, importance: 0)
        }
    }
}
