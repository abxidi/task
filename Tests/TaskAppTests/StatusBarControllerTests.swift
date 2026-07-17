import XCTest
@testable import TaskApp

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testStatusItemActivationUsesSharedWindowActivator() {
        var activations = 0
        let controller = StatusBarController { activations += 1 }

        controller.activateMainWindow(nil)

        XCTAssertEqual(activations, 1)
    }

    func testMissingMainWindowRequestsOpeningTheMainScene() {
        var openRequests = 0
        let activator = TaskWindowActivator(
            mainWindow: { nil },
            openMainWindow: { openRequests += 1 }
        )

        activator.showMainWindow()

        XCTAssertEqual(openRequests, 1)
    }
}
