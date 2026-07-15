import Foundation

enum GlobalShortcutMode: String, Codable, Equatable, Sendable {
    case doubleControl
    case custom
    case disabled
}

enum GlobalShortcutModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case option
    case control
    case shift

    var symbol: String {
        switch self {
        case .command:
            "⌘"
        case .option:
            "⌥"
        case .control:
            "⌃"
        case .shift:
            "⇧"
        }
    }
}

struct GlobalShortcutKeyCombination: Codable, Equatable, Sendable {
    let keyCode: UInt16
    let keyDisplay: String
    let modifiers: Set<GlobalShortcutModifier>

    var displayText: String {
        GlobalShortcutModifier.allCases
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined() + keyDisplay
    }
}

struct GlobalShortcutConfiguration: Codable, Equatable, Sendable {
    static let `default` = GlobalShortcutConfiguration(mode: .doubleControl)

    let mode: GlobalShortcutMode
    let customShortcut: GlobalShortcutKeyCombination?

    init(mode: GlobalShortcutMode = .doubleControl, customShortcut: GlobalShortcutKeyCombination? = nil) {
        self.mode = mode
        self.customShortcut = customShortcut
    }

    var isEnabled: Bool {
        mode != .disabled
    }
}
