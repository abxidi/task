import XCTest
@testable import TaskApp

@MainActor
final class GlobalShortcutManagerTests: XCTestCase {
    func testFailedCustomRegistrationKeepsPreviousActiveConfiguration() {
        let defaults = makeDefaults()
        let registrar = FakeShortcutRegistrar(results: [true, false])
        let manager = GlobalShortcutManager(
            defaults: defaults,
            registrar: registrar,
            inputMonitoringPermission: { true }
        )
        let first = shortcut(keyCode: 40, display: "K")
        let second = shortcut(keyCode: 45, display: "N")

        XCTAssertTrue(manager.apply(.init(mode: .custom, customShortcut: first)))
        XCTAssertFalse(manager.apply(.init(mode: .custom, customShortcut: second)))

        XCTAssertEqual(manager.activeConfiguration, .init(mode: .custom, customShortcut: first))
        XCTAssertEqual(manager.configuration, .init(mode: .custom, customShortcut: first))
        XCTAssertTrue(manager.hasCustomShortcutRegistrationError)
    }

    func testDoubleControlInvokesActivationHandlerOnlyOnce() {
        let defaults = makeDefaults()
        var activationCount = 0
        let manager = GlobalShortcutManager(
            defaults: defaults,
            registrar: FakeShortcutRegistrar(results: []),
            activationHandler: { activationCount += 1 },
            inputMonitoringPermission: { true }
        )

        XCTAssertTrue(manager.apply(.default))
        manager.handleDoubleControlEvent(.controlDown, timestamp: 0)
        manager.handleDoubleControlEvent(.controlUp, timestamp: 0.05)
        manager.handleDoubleControlEvent(.controlDown, timestamp: 0.20)
        manager.handleDoubleControlEvent(.controlUp, timestamp: 0.25)

        XCTAssertEqual(activationCount, 1)
    }

    func testGrantingInputMonitoringPermissionActivatesSelectedDoubleControlShortcut() {
        let defaults = makeDefaults()
        var isAuthorized = false
        let manager = GlobalShortcutManager(
            defaults: defaults,
            registrar: FakeShortcutRegistrar(results: []),
            inputMonitoringPermission: { isAuthorized }
        )

        XCTAssertFalse(manager.apply(.default))
        XCTAssertNil(manager.activeConfiguration)

        isAuthorized = true
        manager.refreshInputMonitoringPermission()

        XCTAssertEqual(manager.activeConfiguration, .default)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "GlobalShortcutManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func shortcut(keyCode: UInt16, display: String) -> GlobalShortcutKeyCombination {
        GlobalShortcutKeyCombination(
            keyCode: keyCode,
            keyDisplay: display,
            modifiers: [.command, .shift]
        )
    }
}

@MainActor
private final class FakeShortcutRegistrar: GlobalShortcutRegistering {
    private var results: [Bool]

    init(results: [Bool]) {
        self.results = results
    }

    func register(
        _ shortcut: GlobalShortcutKeyCombination,
        action: @escaping @MainActor () -> Void
    ) -> GlobalShortcutRegistration? {
        results.removeFirst() ? FakeShortcutRegistration() : nil
    }
}

@MainActor
private final class FakeShortcutRegistration: GlobalShortcutRegistration {
    func unregister() {}
}
