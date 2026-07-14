import XCTest
@testable import TaskNotifications

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskNotificationsModule.self)
    }
}
