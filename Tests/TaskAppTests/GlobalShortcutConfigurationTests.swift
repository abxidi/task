import Foundation
import XCTest
@testable import TaskApp

final class GlobalShortcutConfigurationTests: XCTestCase {
    func testDefaultConfigurationUsesDoubleControl() {
        XCTAssertEqual(GlobalShortcutConfiguration.default.mode, .doubleControl)
        XCTAssertTrue(GlobalShortcutConfiguration.default.isEnabled)
    }

    func testCustomShortcutRoundTripsThroughCodable() throws {
        let shortcut = GlobalShortcutKeyCombination(
            keyCode: 40,
            keyDisplay: "K",
            modifiers: [.command, .shift]
        )
        let configuration = GlobalShortcutConfiguration(mode: .custom, customShortcut: shortcut)

        let decoded = try JSONDecoder().decode(
            GlobalShortcutConfiguration.self,
            from: JSONEncoder().encode(configuration)
        )

        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.customShortcut?.displayText, "⌘⇧K")
    }

    func testDisabledConfigurationDoesNotEnableShortcutRegistration() {
        XCTAssertFalse(GlobalShortcutConfiguration(mode: .disabled).isEnabled)
    }

    func testDoubleControlTriggersOnlyAfterTwoReleasedControlsWithinWindow() {
        var detector = DoubleControlDetector()

        XCTAssertFalse(detector.handle(.controlDown, at: 0))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.05))
        XCTAssertFalse(detector.handle(.controlDown, at: 0.20))
        XCTAssertTrue(detector.handle(.controlUp, at: 0.25))
    }

    func testDoubleControlDoesNotTriggerAfterTimeout() {
        var detector = DoubleControlDetector()

        XCTAssertFalse(detector.handle(.controlDown, at: 0))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.05))
        XCTAssertFalse(detector.handle(.controlDown, at: 0.46))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.50))
    }

    func testDoubleControlDoesNotTriggerWhenAnotherKeyInterruptsSequence() {
        var detector = DoubleControlDetector()

        XCTAssertFalse(detector.handle(.controlDown, at: 0))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.05))
        XCTAssertFalse(detector.handle(.otherKey, at: 0.10))
        XCTAssertFalse(detector.handle(.controlDown, at: 0.20))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.25))
    }

    func testDoubleControlDoesNotTriggerAfterOneReleasedControl() {
        var detector = DoubleControlDetector()

        XCTAssertFalse(detector.handle(.controlDown, at: 0))
        XCTAssertFalse(detector.handle(.controlUp, at: 0.05))
    }
}
