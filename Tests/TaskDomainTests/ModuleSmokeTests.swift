import XCTest
@testable import TaskDomain

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskDomainModule.self)
    }
}
