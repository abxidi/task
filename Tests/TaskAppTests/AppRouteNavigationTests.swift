import XCTest
@testable import TaskApp

final class AppRouteNavigationTests: XCTestCase {
    func testWorkbenchNavigationUsesTheRequestedOrderAndDistributionMapTitle() {
        XCTAssertEqual(
            AppRoute.workbenchNavigation,
            [.focusPool, .taskList, .priorityMap, .projectBoard, .insights]
        )
        XCTAssertEqual(AppRoute.priorityMap.sidebarTitle, "分布地图")
    }

    func testTaskAppShellStartsInFocusPool() {
        XCTAssertEqual(TaskAppShell.defaultRoute, .focusPool)
    }
}
